import * as adminRepository from './admin.repository.js';
import * as authRepository from '../auth/auth.repository.js';
import bcrypt from 'bcryptjs';
import { AppError } from '../../lib/AppError.js';

export const getStores = async () => {
  return adminRepository.getAllStores();
};

export const getUsers = async () => {
  return adminRepository.getAllUsers();
};

export const createManager = async (data) => {
  const existingUser = await authRepository.findUserByEmail(data.email);
  if (existingUser) {
    throw new AppError('Email already in use', 400);
  }

  const passwordHash = await bcrypt.hash(data.password, 12);

  const manager = await authRepository.createUser({
    name: data.name,
    email: data.email,
    passwordHash,
    role: 'MANAGER',
    storeId: data.storeId
  });

  const { passwordHash: _, ...managerWithoutPassword } = manager;
  return managerWithoutPassword;
};

export const getOrders = async () => {
  return adminRepository.getAllOrders();
};
