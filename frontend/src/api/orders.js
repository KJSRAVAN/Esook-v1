import client from './client'
export const createOrder = (data) => client.post('/orders', data)
export const getMyOrders = () => client.get('/orders/my')
export const getStoreOrders = () => client.get('/orders/store')
export const getOrder = (orderId) => client.get(`/orders/${orderId}`)
export const updateOrderStatus = (orderId, status) => client.patch(`/orders/${orderId}/status`, { status })
