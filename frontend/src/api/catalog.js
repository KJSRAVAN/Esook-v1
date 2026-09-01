import client from './client'
export const getCatalog = (storeId) => client.get(`/stores/${storeId}/items`)
export const addCatalogItem = (storeId, data) => client.post(`/stores/${storeId}/items`, data)
export const updateCatalogItem = (storeId, itemId, data) => client.patch(`/stores/${storeId}/items/${itemId}`, data)
