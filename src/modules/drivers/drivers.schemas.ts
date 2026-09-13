import { z } from 'zod';

export const driverStatusSchema = z.object({
  status: z.enum(['OUT_FOR_DELIVERY', 'DELIVERED']),
});

export type DriverStatusDto = z.infer<typeof driverStatusSchema>;