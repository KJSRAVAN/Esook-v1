import { Router } from 'express';
import * as adminController from './admin.controller.js';
import { validate } from '../../middleware/validate.middleware.js';
import { authenticate, requireRole } from '../../middleware/auth.middleware.js';
import { createManagerSchema } from './admin.schema.js';

const router = Router();

router.use(authenticate, requireRole('SUPER_ADMIN'));

router.get('/stores', adminController.getStores);
router.get('/users', adminController.getUsers);
router.post('/managers', validate(createManagerSchema), adminController.createManager);
router.get('/orders', adminController.getOrders);

export default router;
