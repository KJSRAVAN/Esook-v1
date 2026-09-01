import prisma from '../../lib/prisma.js';

export const getAllStores = async () => {
  return prisma.store.findMany({
    include: {
      area: { select: { name: true } },
      _count: {
        select: { users: true, orders: true }
      }
    }
  });
};

export const getAllUsers = async () => {
  return prisma.user.findMany({
    select: {
      id: true, name: true, email: true, phone: true, role: true, storeId: true, createdAt: true,
      store: { select: { name: true } }
    }
  });
};

export const getAllOrders = async () => {
  return prisma.order.findMany({
    orderBy: { createdAt: 'desc' },
    include: {
      store: { select: { name: true } },
      customer: { select: { name: true, email: true } }
    }
  });
};
