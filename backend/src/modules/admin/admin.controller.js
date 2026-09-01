import * as adminService from './admin.service.js';

export const getStores = async (req, res, next) => {
  try {
    const stores = await adminService.getStores();
    res.json(stores);
  } catch (error) {
    next(error);
  }
};

export const getUsers = async (req, res, next) => {
  try {
    const users = await adminService.getUsers();
    res.json(users);
  } catch (error) {
    next(error);
  }
};

export const createManager = async (req, res, next) => {
  try {
    const manager = await adminService.createManager(req.body);
    res.status(201).json(manager);
  } catch (error) {
    next(error);
  }
};

export const getOrders = async (req, res, next) => {
  try {
    const orders = await adminService.getOrders();
    res.json(orders);
  } catch (error) {
    next(error);
  }
};
