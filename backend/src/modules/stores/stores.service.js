import * as storesRepository from './stores.repository.js';

export const getStores = async (areaId) => {
  return storesRepository.findStores(areaId);
};

export const getAreas = async () => {
  return storesRepository.findAreas();
};
