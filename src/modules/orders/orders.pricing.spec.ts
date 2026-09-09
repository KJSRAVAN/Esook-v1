import { computePricing } from './orders.pricing';
import { Decimal } from '@prisma/client/runtime/library';

describe('computePricing', () => {
  const items = [
    { itemId: '1', name: 'Milk', price: new Decimal('5.50'), quantity: 2 },
    { itemId: '2', name: 'Bread', price: new Decimal('12.00'), quantity: 1 },
  ];

  it('calculates subtotal: 5.50*2 + 12.00 = 23.00', () => {
    const { subtotal } = computePricing(items, new Decimal(0));
    expect(subtotal.toFixed(2)).toBe('23.00');
  });

  it('applies flat discount correctly', () => {
    const { discount, total } = computePricing(items, new Decimal('5'));
    expect(discount.toFixed(2)).toBe('5.00');
    expect(total.toFixed(2)).toBe('18.00');
  });

  it('caps discount at subtotal (no negative total)', () => {
    const { discount, total } = computePricing(items, new Decimal('999'));
    expect(discount.toFixed(2)).toBe('23.00');
    expect(total.toFixed(2)).toBe('0.00');
  });

  it('builds itemName and quantity snapshot correctly', () => {
    const { orderItems } = computePricing(items, new Decimal(0));
    expect(orderItems[0].itemName).toBe('Milk');
    expect(orderItems[0].quantity).toBe(2);
    expect(orderItems[1].itemName).toBe('Bread');
  });

  it('zero discount returns subtotal as total', () => {
    const { subtotal, total, discount } = computePricing(items, new Decimal(0));
    expect(discount.toFixed(2)).toBe('0.00');
    expect(total.toFixed(2)).toBe(subtotal.toFixed(2));
  });
});
