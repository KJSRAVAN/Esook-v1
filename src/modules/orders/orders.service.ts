import {
  Injectable, NotFoundException, ForbiddenException,
  BadRequestException, Logger,
} from '@nestjs/common';
import { PrismaService } from '@shared/database/prisma.service';
import { OrdersRepository } from './orders.repository';
import { CreateOrderDto, UpdateOrderStatusDto, OrderQueryDto } from './orders.schemas';
import { computePricing } from './orders.pricing';
import { Decimal } from '@prisma/client/runtime/library';

interface AuthUser { id: string; role: string; storeId: string | null; }

@Injectable()
export class OrdersService {
  private readonly logger = new Logger(OrdersService.name);

  constructor(
    private readonly repo: OrdersRepository,
    private readonly prisma: PrismaService,
  ) {}

  async createOrder(dto: CreateOrderDto, customerId: string, idempotencyKey?: string) {
    // Idempotency check — return existing order if key already used
    if (idempotencyKey) {
      const existing = await this.repo.findByIdempotencyKey(idempotencyKey);
      if (existing) return existing;
    }

    const order = await this.prisma.$transaction(async (tx) => {
      // 1. Validate items exist and are available in the requested store
      const itemIds = dto.items.map((i) => i.itemId);
      const dbItems = await tx.item.findMany({
        where: { id: { in: itemIds }, storeId: dto.storeId, isAvailable: true },
      });

      if (dbItems.length !== dto.items.length) {
        const missing = dto.items.filter((r) => !dbItems.find((d) => d.id === r.itemId));
        throw new BadRequestException({
          code: 'ITEMS_UNAVAILABLE',
          message: 'One or more items are not available',
          details: missing.map((m) => ({ itemId: m.itemId, reason: 'not found or unavailable' })),
        });
      }

      // 2. Build price-snapshot list
      const pricedItems = dto.items.map((r) => {
        const db = dbItems.find((d) => d.id === r.itemId)!;
        return { itemId: db.id, name: db.name, price: db.price, quantity: r.quantity };
      });

      // 3. Coupon resolution (inside transaction for atomic usedCount increment)
      let couponDiscount = new Decimal(0);
      let couponId: string | null = null;

      if (dto.couponCode) {
        const coupon = await tx.coupon.findUnique({ where: { code: dto.couponCode } });
        if (!coupon || !coupon.isActive)
          throw new BadRequestException({ code: 'COUPON_INVALID', message: 'Invalid coupon' });
        if (coupon.expiresAt && coupon.expiresAt < new Date())
          throw new BadRequestException({ code: 'COUPON_EXPIRED', message: 'Coupon expired' });
        if (coupon.maxUses !== null && coupon.usedCount >= coupon.maxUses)
          throw new BadRequestException({ code: 'COUPON_EXHAUSTED', message: 'Coupon limit reached' });

        const rawSubtotal = pricedItems.reduce((s, i) => s + Number(i.price) * i.quantity, 0);
        if (coupon.minOrderValue && rawSubtotal < Number(coupon.minOrderValue))
          throw new BadRequestException({
            code: 'COUPON_MIN_ORDER',
            message: `Minimum order for this coupon is ${coupon.minOrderValue}`,
          });

        couponId = coupon.id;
        couponDiscount = coupon.discountType === 'PERCENT'
          ? new Decimal(rawSubtotal).mul(coupon.discountValue).div(100)
          : new Decimal(coupon.discountValue);

        await tx.coupon.update({ where: { id: coupon.id }, data: { usedCount: { increment: 1 } } });
      }

      // 4. Pricing
      const { orderItems, subtotal, discount, total } = computePricing(pricedItems, couponDiscount);

      // 5. Create order
      return tx.order.create({
        data: {
          idempotencyKey: idempotencyKey ?? null,
          customerId, storeId: dto.storeId,
          status: 'PENDING',
          fulfillment: dto.fulfillment,
          deliveryAddress: dto.deliveryAddress,
          couponId, subtotal, discount, total,
          notes: dto.notes,
          items: { create: orderItems },
        },
        include: {
          customer: { select: { id: true, name: true, phone: true } },
          store: { select: { id: true, name: true } },
          items: true,
          coupon: { select: { code: true } },
        },
      });
    });

    await this.repo.writeAuditLog({
      entity: 'order', entityId: order.id, action: 'created',
      actorId: customerId, orderId: order.id,
      metadata: { total: order.total.toString(), itemCount: dto.items.length },
    });

    this.logger.log(`Order created: ${order.id}`);
    return order;
  }

  getMyOrders(customerId: string, query: OrderQueryDto) {
    return this.repo.findForCustomer(customerId, query);
  }

  getStoreOrders(storeId: string, query: OrderQueryDto, actor: AuthUser) {
    this.assertStoreAccess(actor, storeId);
    return this.repo.findForStore(storeId, query);
  }

  async getOrderById(id: string, actor: AuthUser) {
    const order = await this.repo.findById(id);
    if (!order) throw new NotFoundException('Order not found');
    this.assertOrderAccess(actor, order);
    return order;
  }

  async updateStatus(id: string, dto: UpdateOrderStatusDto, actor: AuthUser) {
    const order = await this.repo.findById(id);
    if (!order) throw new NotFoundException('Order not found');
    if (actor.role === 'CUSTOMER') throw new ForbiddenException();
    this.assertStoreAccess(actor, order.storeId);

    // Both the status update and audit log must succeed together.
    // If the audit log fails, the status change is rolled back.
    const [updated] = await this.prisma.$transaction([
      this.prisma.order.update({
        where: { id },
        data: {
          status: dto.status as import('@prisma/client').OrderStatus,
          ...(dto.rejectedReason ? { rejectedReason: dto.rejectedReason } : {}),
        },
        include: {
          customer: { select: { id: true, name: true, phone: true } },
          store: { select: { id: true, name: true } },
          items: true,
          coupon: { select: { code: true, discountType: true, discountValue: true } },
        },
      }),
      this.prisma.auditLog.create({
        data: {
          entity: 'order', entityId: id, action: 'status_changed',
          actorId: actor.id, orderId: id,
          metadata: { from: order.status, to: dto.status },
        },
      }),
    ]);

    return updated;
  }

  private assertStoreAccess(actor: AuthUser, storeId: string): void {
    if (actor.role === 'SUPER_ADMIN') return;
    if (actor.storeId !== storeId)
      throw new ForbiddenException('Access to this store is not allowed');
  }

  private assertOrderAccess(actor: AuthUser, order: { customerId: string; storeId: string }): void {
    if (actor.role === 'SUPER_ADMIN') return;
    if (actor.role === 'CUSTOMER' && order.customerId !== actor.id)
      throw new ForbiddenException();
    if (['STAFF', 'MANAGER'].includes(actor.role) && order.storeId !== actor.storeId)
      throw new ForbiddenException();
  }
}
