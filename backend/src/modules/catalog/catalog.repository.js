import prisma from '../../lib/prisma.js';

export const getItemsByStore = async (storeId, allItems = false) => {
  const where = { storeId };
  if (!allItems) {
    where.isAvailable = true;
  }
  return prisma.item.findMany({ where });
};

export const updateItem = async (itemId, storeId, data) => {
  return prisma.item.update({
    where: { id: itemId, storeId },
    data
  });
};

export const createItem = async (storeId, data) => {
  return prisma.item.create({
    data: {
      ...data,
      storeId
    }
  });
};
