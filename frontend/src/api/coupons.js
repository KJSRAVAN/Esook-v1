import client from './client'
export const validateCoupon = (data) => client.post('/coupons/validate', data)
