import { Router } from 'express';
import * as storesController from './stores.controller.js';

const router = Router();

// Define /areas BEFORE /:storeId to avoid conflict if we add /:storeId later
router.get('/areas', storesController.getAreas);
router.get('/', storesController.getStores);

export default router;
