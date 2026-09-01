import * as catalogService from './catalog.service.js';
import jwt from 'jsonwebtoken';

// Optional auth helper for GET /items
const getOptionalUser = (req) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    try {
      const token = authHeader.split(' ')[1];
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'change-me-before-production');
      return { role: decoded.role, storeId: decoded.storeId };
    } catch (e) {
      return null;
    }
  }
  return null;
};

export const getItems = async (req, res, next) => {
  try {
    const { storeId } = req.params;
    const user = getOptionalUser(req);
    const items = await catalogService.getItems(storeId, user);
    res.json(items);
  } catch (error) {
    next(error);
  }
};

export const updateItem = async (req, res, next) => {
  try {
    const { storeId, itemId } = req.params;
    const item = await catalogService.updateItem(itemId, storeId, req.user, req.body);
    res.json(item);
  } catch (error) {
    next(error);
  }
};

export const createItem = async (req, res, next) => {
  try {
    const { storeId } = req.params;
    const item = await catalogService.createItem(storeId, req.user, req.body);
    res.status(201).json(item);
  } catch (error) {
    next(error);
  }
};
