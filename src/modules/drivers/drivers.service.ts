import {
  Injectable, NotFoundException, ForbiddenException,
  ConflictException, BadRequestException, Logger,
} from '@nestjs/common';
import { PrismaService } from '@shared/database/prisma.service';
import { DriverStatusDto } from './drivers.schemas';
import { Prisma } from '@prisma/client';

/** Fields returned to a driver — only what is needed for delivery, no pricing details */
const DRIVER_ORDER_SELECT = {
  id: true,
  status: true,
  fulfillment: true,
  deliveryAddress: true,
  notes: true,
  driverId: true,
  createdAt: true,
  store: { select: { id: true, name: true, address: true, phone: true } },
  customer: { select: { phone: true } },
} satisfies Prisma.OrderSelect;

@Injectable()
export class DriversService {
  private readonly logger = new Logger(DriversService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Returns all DELIVERY orders in READY state with no driver assigned.
   * Platform-wide — not store-scoped.
   */
  getAvailableOrders() {
    return this.prisma.order.findMany({
      where: { status: 'READY', fulfillment: 'DELIVERY', driverId: null },
      select: DRIVER_ORDER_SELECT,
      orderBy: { createdAt: 'asc' }, // oldest first — fairness
    });
  }

  /**
   * Returns the driver's single active in-progress order (if any).
   */
  getActiveOrder(driverId: string) {
    return this.prisma.order.findFirst({
      where: { driverId, status: 'OUT_FOR_DELIVERY' },
      select: DRIVER_ORDER_SELECT,
    });
  }

  /**
   * Self-assign: atomically claim an unassigned READY DELIVERY order.
   *
   * Race condition protection: uses updateMany with WHERE driverId IS NULL + status = READY.
   * If another driver claims the order first, count = 0 and we throw 409.
   *
   * One active order limit: driver cannot accept while they have an OUT_FOR_DELIVERY order.
   */
  async acceptOrder(orderId: string, driverId: string) {
    // Enforce 1-active-order rule
    const active = await this.prisma.order.findFirst({
      where: { driverId, status: 'OUT_FOR_DELIVERY' },
      select: { id: true },
    });
    if (active) {
      throw new ConflictException({
        code: 'DRIVER_BUSY',
        message: 'You already have an active delivery. Complete it before accepting another.',
      });
    }

    // Atomic self-assign — only succeeds if order is still unclaimed
    const result = await this.prisma.order.updateMany({
      where: { id: orderId, status: 'READY', fulfillment: 'DELIVERY', driverId: null },
      data: { driverId, status: 'OUT_FOR_DELIVERY' },
    });

    if (result.count === 0) {
      // Order doesn't exist, not READY, not DELIVERY, or already claimed
      const order = await this.prisma.order.findUnique({ where: { id: orderId }, select: { id: true, status: true, fulfillment: true } });
      if (!order) throw new NotFoundException('Order not found');
      if (order.fulfillment !== 'DELIVERY') throw new BadRequestException({ code: 'NOT_DELIVERY', message: 'This order is not a delivery order' });
      throw new ConflictException({ code: 'ORDER_UNAVAILABLE', message: 'Order is no longer available for pickup' });
    }

    await this.prisma.auditLog.create({
      data: {
        entity: 'order', entityId: orderId, action: 'driver_assigned',
        actorId: driverId, orderId, metadata: { driverId },
      },
    });

    this.logger.log(`Driver ${driverId} accepted order ${orderId}`);

    return this.prisma.order.findUnique({ where: { id: orderId }, select: DRIVER_ORDER_SELECT });
  }

  /**
   * Driver updates delivery status.
   * Allowed transitions: OUT_FOR_DELIVERY → DELIVERED only.
   * (The READY → OUT_FOR_DELIVERY transition happens at accept time.)
   */
  async updateStatus(orderId: string, dto: DriverStatusDto, driverId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: { id: true, driverId: true, status: true },
    });

    if (!order) throw new NotFoundException('Order not found');
    if (order.driverId !== driverId) throw new ForbiddenException('This order is not assigned to you');

    // Only allow valid driver transitions
    const allowed: Record<string, string[]> = {
      OUT_FOR_DELIVERY: ['DELIVERED'],
    };
    if (!allowed[order.status]?.includes(dto.status)) {
      throw new BadRequestException({
        code: 'INVALID_TRANSITION',
        message: `Cannot transition from ${order.status} to ${dto.status}`,
      });
    }

    const [updated] = await this.prisma.$transaction([
      this.prisma.order.update({
        where: { id: orderId },
        data: { status: dto.status as import('@prisma/client').OrderStatus },
        select: DRIVER_ORDER_SELECT,
      }),
      this.prisma.auditLog.create({
        data: {
          entity: 'order', entityId: orderId, action: 'status_changed',
          actorId: driverId, orderId,
          metadata: { from: order.status, to: dto.status, by: 'driver' },
        },
      }),
    ]);

    this.logger.log(`Driver ${driverId} updated order ${orderId} → ${dto.status}`);
    return updated;
  }
}