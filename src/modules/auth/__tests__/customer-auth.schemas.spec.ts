import {
  customerSignupSchema,
  customerVerifyEmailSchema,
  customerLoginSchema,
  customerRequestPasswordResetSchema,
  customerResetPasswordSchema,
} from '../auth.schemas';

describe('Customer Auth Schemas Validation', () => {
  describe('customerSignupSchema', () => {
    it('accepts valid customer registration details with Saudi phone', () => {
      const result = customerSignupSchema.safeParse({
        name: 'Ahmed Ali',
        email: 'ahmed@example.com',
        phone: '+966501234567',
        password: 'Password@123',
      });
      expect(result.success).toBe(true);
    });

    it('accepts valid customer registration details with Indian phone (+91)', () => {
      const result = customerSignupSchema.safeParse({
        name: 'Raj Sharma',
        email: 'raj@example.com',
        phone: '+919876543210',
        password: 'Password@123',
      });
      expect(result.success).toBe(true);
    });

    it('rejects short passwords (< 8 characters)', () => {
      const result = customerSignupSchema.safeParse({
        name: 'Ahmed',
        email: 'ahmed@example.com',
        phone: '+966501234567',
        password: 'Pass1',
      });
      expect(result.success).toBe(false);
    });

    it('rejects invalid email formats', () => {
      const result = customerSignupSchema.safeParse({
        name: 'Ahmed',
        email: 'not-an-email',
        phone: '+966501234567',
        password: 'Password@123',
      });
      expect(result.success).toBe(false);
    });

    it('rejects local phone format without country code', () => {
      const result = customerSignupSchema.safeParse({
        name: 'Ahmed',
        email: 'ahmed@example.com',
        phone: '0501234567',
        password: 'Password@123',
      });
      expect(result.success).toBe(false);
    });
  });

  describe('customerLoginSchema', () => {
    it('accepts email + password', () => {
      const result = customerLoginSchema.safeParse({
        email: 'customer@example.com',
        password: 'Password@123',
      });
      expect(result.success).toBe(true);
    });

    it('accepts phone + password', () => {
      const result = customerLoginSchema.safeParse({
        phone: '+966501234567',
        password: 'Password@123',
      });
      expect(result.success).toBe(true);
    });

    it('rejects if neither email nor phone is provided', () => {
      const result = customerLoginSchema.safeParse({
        password: 'Password@123',
      });
      expect(result.success).toBe(false);
    });
  });

  describe('customerVerifyEmailSchema', () => {
    it('accepts email and 6-digit code', () => {
      const result = customerVerifyEmailSchema.safeParse({
        email: 'customer@example.com',
        code: '123456',
      });
      expect(result.success).toBe(true);
    });

    it('rejects non-numeric code or code of incorrect length', () => {
      expect(
        customerVerifyEmailSchema.safeParse({ email: 'c@ex.com', code: '12345' }).success,
      ).toBe(false);
      expect(
        customerVerifyEmailSchema.safeParse({ email: 'c@ex.com', code: 'abcdef' }).success,
      ).toBe(false);
    });
  });

  describe('customerResetPasswordSchema', () => {
    it('accepts valid email, 6-digit code, and new strong password', () => {
      const result = customerResetPasswordSchema.safeParse({
        email: 'customer@example.com',
        code: '654321',
        newPassword: 'BrandNewSecret@123',
      });
      expect(result.success).toBe(true);
    });
  });
});
