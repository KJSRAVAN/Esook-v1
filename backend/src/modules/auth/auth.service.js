import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { AppError } from '../../lib/AppError.js';
import * as authRepository from './auth.repository.js';

const generateToken = (user) => {
  return jwt.sign(
    { sub: user.id, email: user.email, role: user.role, storeId: user.storeId },
    process.env.JWT_SECRET || 'change-me-before-production',
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
};

export const register = async (data) => {
  const existingUser = await authRepository.findUserByEmail(data.email);
  if (existingUser) {
    throw new AppError('Email already in use', 400);
  }

  const passwordHash = await bcrypt.hash(data.password, 12);

  const user = await authRepository.createUser({
    name: data.name,
    email: data.email,
    phone: data.phone,
    passwordHash,
    role: 'CUSTOMER'
  });

  const token = generateToken(user);
  
  const { passwordHash: _, ...userWithoutPassword } = user;
  
  return { token, user: userWithoutPassword };
};

export const login = async ({ email, password }) => {
  const user = await authRepository.findUserByEmail(email);
  if (!user) {
    throw new AppError('Invalid credentials', 401);
  }

  const isPasswordValid = await bcrypt.compare(password, user.passwordHash);
  if (!isPasswordValid) {
    throw new AppError('Invalid credentials', 401);
  }

  const token = generateToken(user);
  
  const { passwordHash: _, ...userWithoutPassword } = user;

  return { token, user: userWithoutPassword };
};

export const getMe = async (userId) => {
  const user = await authRepository.findUserById(userId);
  if (!user) {
    throw new AppError('User not found', 404);
  }
  return user;
};
