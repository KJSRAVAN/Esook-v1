import { AppError } from '../../lib/AppError.js';
import * as couponsRepository from './coupons.repository.js';

export const validateCoupon = async (code, subtotal) => {
  const coupon = await couponsRepository.findCouponByCode(code);
  
  if (!coupon || !coupon.isActive) {
    return { valid: false, message: 'Invalid or inactive coupon' };
  }
  
  if (coupon.expiresAt && new Date(coupon.expiresAt) < new Date()) {
    return { valid: false, message: 'Coupon expired' };
  }
  
  if (coupon.maxUses !== null && coupon.usedCount >= coupon.maxUses) {
    return { valid: false, message: 'Coupon usage limit reached' };
  }
  
  if (coupon.minOrderValue !== null && parseFloat(subtotal) < parseFloat(coupon.minOrderValue)) {
    return { valid: false, message: `Minimum order value of ${coupon.minOrderValue} required` };
  }
  
  let discount = 0;
  if (coupon.discountType === 'PERCENT') {
    discount = (parseFloat(subtotal) * parseFloat(coupon.discountValue)) / 100;
  } else if (coupon.discountType === 'FLAT') {
    discount = Math.min(parseFloat(coupon.discountValue), parseFloat(subtotal));
  }
  
  const newTotal = parseFloat(subtotal) - discount;
  
  return {
    valid: true,
    discountType: coupon.discountType,
    discountValue: coupon.discountValue,
    discount,
    newTotal,
    message: 'Coupon applied successfully'
  };
};
