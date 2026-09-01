import { Router } from 'express';
import authRoutes from './modules/auth/auth.routes.js';
import storesRoutes from './modules/stores/stores.routes.js';
import catalogRoutes from './modules/catalog/catalog.routes.js';
import ordersRoutes from './modules/orders/orders.routes.js';
import couponsRoutes from './modules/coupons/coupons.routes.js';
import adminRoutes from './modules/admin/admin.routes.js';

const router = Router();

router.use('/auth', authRoutes);
router.use('/stores', storesRoutes);
router.use('/stores', catalogRoutes); // Mounted at stores for /stores/:storeId/items
router.use('/orders', ordersRoutes);
router.use('/coupons', couponsRoutes);
router.use('/admin', adminRoutes);

export default router;
