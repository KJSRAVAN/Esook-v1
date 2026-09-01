import prisma from '../../lib/prisma.js';

export const createOrder = async (orderData) => {
  return prisma.$transaction(async (tx) => {
    const order = await tx.order.create({
      data: orderData
    });
    if (orderData.couponId) {
      await tx.coupon.update({
        where: { id: orderData.couponId },
        data: { usedCount: { increment: 1 } }
      });
    }
    return order;
  });
};

export const getCustomerOrders = async (customerId) => {
  return prisma.order.findMany({
    where: { customerId },
    orderBy: { createdAt: 'desc' },
    include: {
      items: true,
      store: { select: { name: true } }
    }
  });
};

export const getStoreOrders = async (storeId) => {
  return prisma.order.findMany({
    where: { storeId },
    orderBy: { createdAt: 'desc' },
    include: {
      items: true,
      customer: { select: { name: true, email: true, phone: true } }
    }
  });
};

export const getOrderById = async (id) => {
  return prisma.order.findUnique({
    where: { id },
    include: {
      items: true,
      customer: { select: { name: true, email: true, phone: true } },
      store: { select: { name: true } }
    }
  });
};

export const updateOrderStatus = async (id, status) => {
  return prisma.order.update({
    where: { id },
    data: { status }
  });
};
