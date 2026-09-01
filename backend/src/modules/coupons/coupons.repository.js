import prisma from '../../lib/prisma.js';

export const findCouponByCode = async (code) => {
  return prisma.coupon.findUnique({ where: { code } });
};
