import { AppError } from '../../lib/AppError.js';
import * as catalogRepository from './catalog.repository.js';

const checkScope = (user, storeId) => {
  if (user.role !== 'SUPER_ADMIN' && user.storeId !== storeId) {
    throw new AppError('Forbidden: Not assigned to this store', 403);
  }
};

export const getItems = async (storeId, user) => {
  const showAllItems = user && (user.role === 'MANAGER' || user.role === 'SUPER_ADMIN' || user.role === 'STAFF');
  return catalogRepository.getItemsByStore(storeId, showAllItems);
};

export const updateItem = async (itemId, storeId, user, data) => {
  checkScope(user, storeId);
  try {
    return await catalogRepository.updateItem(itemId, storeId, data);
  } catch (error) {
    throw new AppError('Item not found or could not be updated', 404);
  }
};

export const createItem = async (storeId, user, data) => {
  checkScope(user, storeId);
  return catalogRepository.createItem(storeId, data);
};
