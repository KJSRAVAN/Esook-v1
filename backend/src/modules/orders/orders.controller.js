import * as ordersService from './orders.service.js';

export const createOrder = async (req, res, next) => {
  try {
    const order = await ordersService.createOrder(req.user, req.body);
    res.status(201).json(order);
  } catch (error) {
    next(error);
  }
};

export const getMyOrders = async (req, res, next) => {
  try {
    const orders = await ordersService.getMyOrders(req.user.id);
    res.json(orders);
  } catch (error) {
    next(error);
  }
};

export const getStoreOrders = async (req, res, next) => {
  try {
    const orders = await ordersService.getStoreOrders(req.user.storeId);
    res.json(orders);
  } catch (error) {
    next(error);
  }
};

export const getOrderById = async (req, res, next) => {
  try {
    const order = await ordersService.getOrderById(req.params.orderId, req.user);
    res.json(order);
  } catch (error) {
    next(error);
  }
};

export const updateOrderStatus = async (req, res, next) => {
  try {
    const order = await ordersService.updateOrderStatus(req.params.orderId, req.body.status, req.user);
    res.json(order);
  } catch (error) {
    next(error);
  }
};
