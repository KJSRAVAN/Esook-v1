import { Injectable } from '@nestjs/common';
import { PrismaService } from '@shared/database/prisma.service';
import { OrderQueryDto } from './orders.schemas';
import { Prisma } from '@prisma/client';

const ORDER_INCLUDE = {
  customer: { select: { id: true, name: true, phone: true } },
  store: { select: { id: true, name: true } },
  items: true,
  coupon: { select: { code: true, discountType: true, discountValue: true } },
} satisfies Prisma.OrderInclude;

@Injectable()
export class OrdersRepository {
  constructor(private readonly prisma: PrismaService) {}

  findById(id: string) {
    return this.prisma.order.findUnique({ where: { id }, include: ORDER_INCLUDE });
  }

  findByIdempotencyKey(key: string) {
    return this.prisma.order.findUnique({
      where: { idempotencyKey: key },
      include: ORDER_INCLUDE,
    });
  }

  async findForCustomer(customerId: string, query: OrderQueryDto) {
    const skip = (query.page - 1) * query.limit;
    const where = { customerId, ...(query.status ? { status: query.status } : {}) };
    const [data, total] = await this.prisma.$transaction([
      this.prisma.order.findMany({
        where, include: ORDER_INCLUDE, orderBy: { createdAt: 'desc' }, skip, take: query.limit,
      }),
      this.prisma.order.count({ where }),
    ]);
    return { data, total, page: query.page, limit: query.limit };
  }

  async findForStore(storeId: string, query: OrderQueryDto) {
    const skip = (query.page - 1) * query.limit;
    const where = { storeId, ...(query.status ? { status: query.status } : {}) };
    const [data, total] = await this.prisma.$transaction([
      this.prisma.order.findMany({
        where, include: ORDER_INCLUDE, orderBy: { createdAt: 'desc' }, skip, take: query.limit,
      }),
      this.prisma.order.count({ where }),
    ]);
    return { data, total, page: query.page, limit: query.limit };
  }

  createOrder(data: Prisma.OrderCreateInput) {
    return this.prisma.order.create({ data, include: ORDER_INCLUDE });
  }

  updateStatus(id: string, status: string, rejectedReason?: string) {
    return this.prisma.order.update({
      where: { id },
      data: {
        status: status as Prisma.EnumOrderStatusFilter['equals'],
        ...(rejectedReason ? { rejectedReason } : {}),
      },
      include: ORDER_INCLUDE,
    });
  }

  writeAuditLog(data: {
    entity: string; entityId: string; action: string;
    actorId?: string; orderId?: string; metadata?: Prisma.InputJsonValue;
  }) {
    return this.prisma.auditLog.create({
      data: {
        entity: data.entity, entityId: data.entityId, action: data.action,
        actorId: data.actorId, orderId: data.orderId, metadata: data.metadata ?? {},
      },
    });
  }
}
