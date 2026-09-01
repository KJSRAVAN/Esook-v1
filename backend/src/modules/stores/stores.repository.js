import prisma from '../../lib/prisma.js';

export const findStores = async (areaId) => {
  const where = { isActive: true };
  if (areaId) {
    where.areaId = areaId;
  }
  return prisma.store.findMany({
    where,
    include: {
      area: { select: { name: true } }
    }
  });
};

export const findAreas = async () => {
  return prisma.area.findMany();
};
