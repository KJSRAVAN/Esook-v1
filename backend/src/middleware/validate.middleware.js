import { AppError } from '../lib/AppError.js';

export const validate = (schema) => {
  return (req, res, next) => {
    try {
      schema.parse(req.body);
      next();
    } catch (error) {
      next(new AppError(error.errors.map(e => e.message).join(', '), 400));
    }
  };
};
