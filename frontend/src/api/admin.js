import client from './client'
export const getAdminStores = () => client.get('/admin/stores')
export const getAdminUsers = () => client.get('/admin/users')
export const createManager = (data) => client.post('/admin/managers', data)
export const getAdminOrders = () => client.get('/admin/orders')
