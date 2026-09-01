import * as storesService from './stores.service.js';

export const getStores = async (req, res, next) => {
  try {
    const areaId = req.query.areaId;
    const stores = await storesService.getStores(areaId);
    res.json(stores);
  } catch (error) {
    next(error);
  }
};

export const getAreas = async (req, res, next) => {
  try {
    const areas = await storesService.getAreas();
    res.json(areas);
  } catch (error) {
    next(error);
  }
};
