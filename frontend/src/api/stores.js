import client from './client'
export const getStores = (areaId) => client.get('/stores' + (areaId ? `?areaId=${areaId}` : ''))
export const getAreas = () => client.get('/stores/areas')
