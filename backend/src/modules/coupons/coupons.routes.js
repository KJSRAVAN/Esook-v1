import { Router } from 'express';
import * as couponsController from './coupons.controller.js';
import { authenticate, requireRole } from '../../middleware/auth.middleware.js';

const router = Router();

router.post('/validate', authenticate, requireRole('CUSTOMER'), couponsController.validateCoupon);

export default router;
