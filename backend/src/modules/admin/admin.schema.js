import { z } from 'zod';

export const createManagerSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(8),
  storeId: z.string().min(1)
});
