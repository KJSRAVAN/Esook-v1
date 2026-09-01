import { Router } from 'express';
import * as ordersController from './orders.controller.js';
import { validate } from '../../middleware/validate.middleware.js';
import { authenticate, requireRole } from '../../middleware/auth.middleware.js';
import { createOrderSchema, updateOrderStatusSchema } from './orders.schema.js';

const router = Router();

router.post('/', authenticate, requireRole('CUSTOMER'), validate(createOrderSchema), ordersController.createOrder);
router.get('/my', authenticate, requireRole('CUSTOMER'), ordersController.getMyOrders);
router.get('/store', authenticate, requireRole('STAFF', 'MANAGER'), ordersController.getStoreOrders);
router.get('/:orderId', authenticate, ordersController.getOrderById);
router.patch('/:orderId/status', authenticate, requireRole('STAFF', 'MANAGER'), validate(updateOrderStatusSchema), ordersController.updateOrderStatus);

export default router;
