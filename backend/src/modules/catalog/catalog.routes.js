import { Router } from 'express';
import * as catalogController from './catalog.controller.js';
import { validate } from '../../middleware/validate.middleware.js';
import { authenticate, requireRole } from '../../middleware/auth.middleware.js';
import { createItemSchema, updateItemSchema } from './catalog.schema.js';

// Mounted at /api/stores in router.js, so this receives /:storeId/items
const router = Router();

router.get('/:storeId/items', catalogController.getItems);

router.post(
  '/:storeId/items',
  authenticate,
  requireRole('MANAGER', 'SUPER_ADMIN'),
  validate(createItemSchema),
  catalogController.createItem
);

router.patch(
  '/:storeId/items/:itemId',
  authenticate,
  requireRole('MANAGER', 'SUPER_ADMIN'),
  validate(updateItemSchema),
  catalogController.updateItem
);

export default router;
