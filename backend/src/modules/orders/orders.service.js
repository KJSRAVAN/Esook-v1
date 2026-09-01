import { AppError } from '../../lib/AppError.js';
import * as ordersRepository from './orders.repository.js';
import * as catalogRepository from '../catalog/catalog.repository.js';
import * as couponsRepository from '../coupons/coupons.repository.js';
import { validateCoupon } from '../coupons/coupons.service.js';

export const createOrder = async (user, data) => {
  // Fetch items
  const items = await catalogRepository.getItemsByStore(data.storeId, false);
  
  let subtotal = 0;
  const orderItemsData = [];

  for (const requestedItem of data.items) {
    const item = items.find(i => i.id === requestedItem.itemId);
    if (!item) {
      throw new AppError(`Item ${requestedItem.itemId} not available`, 400);
    }
    const itemPrice = parseFloat(item.price);
    subtotal += itemPrice * requestedItem.quantity;

    orderItemsData.push({
      itemId: item.id,
      itemName: item.name,
      itemPrice: item.price,
      quantity: requestedItem.quantity
    });
  }

  let discount = 0;
  let couponId = null;

  if (data.couponCode) {
    const couponValidation = await validateCoupon(data.couponCode, subtotal);
    if (!couponValidation.valid) {
      throw new AppError(couponValidation.message, 400);
    }
    discount = couponValidation.discount;
    const coupon = await couponsRepository.findCouponByCode(data.couponCode);
    couponId = coupon.id;
  }

  const total = subtotal - discount;

  const orderData = {
    customerId: user.id,
    storeId: data.storeId,
    fulfillment: data.fulfillment,
    deliveryAddress: data.deliveryAddress,
    couponId,
    subtotal,
    discount,
    total,
    notes: data.notes,
    items: {
      create: orderItemsData
    }
  };

  return ordersRepository.createOrder(orderData);
};

export const getMyOrders = async (userId) => {
  return ordersRepository.getCustomerOrders(userId);
};

export const getStoreOrders = async (storeId) => {
  return ordersRepository.getStoreOrders(storeId);
};

export const getOrderById = async (orderId, user) => {
  const order = await ordersRepository.getOrderById(orderId);
  if (!order) {
    throw new AppError('Order not found', 404);
  }

  // Access control
  if (user.role === 'CUSTOMER' && order.customerId !== user.id) {
    throw new AppError('Forbidden', 403);
  }
  if (['STAFF', 'MANAGER'].includes(user.role) && order.storeId !== user.storeId) {
    throw new AppError('Forbidden', 403);
  }

  return order;
};

export const updateOrderStatus = async (orderId, status, user) => {
  const order = await ordersRepository.getOrderById(orderId);
  if (!order) {
    throw new AppError('Order not found', 404);
  }
  
  if (order.storeId !== user.storeId) {
    throw new AppError('Forbidden', 403);
  }

  return ordersRepository.updateOrderStatus(orderId, status);
};
