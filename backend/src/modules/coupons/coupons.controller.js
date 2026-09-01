import * as couponsService from './coupons.service.js';

export const validateCoupon = async (req, res, next) => {
  try {
    const { code, subtotal } = req.body;
    if (!code || subtotal === undefined) {
      return res.status(400).json({ success: false, message: 'Code and subtotal are required' });
    }
    const result = await couponsService.validateCoupon(code, subtotal);
    res.json(result);
  } catch (error) {
    next(error);
  }
};
