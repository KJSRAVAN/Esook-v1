import { Decimal } from '@prisma/client/runtime/library';

export interface PricedItem {
  itemId: string;
  name: string;
  price: Decimal;
  quantity: number;
}

export interface PricingResult {
  orderItems: { itemId: string; itemName: string; itemPrice: Decimal; quantity: number }[];
  subtotal: Decimal;
  discount: Decimal;
  total: Decimal;
}

/**
 * Pure pricing function -- no side effects, easy to unit-test.
 */
export function computePricing(
  pricedItems: PricedItem[],
  couponDiscount: Decimal,
): PricingResult {
  const subtotal = pricedItems.reduce(
    (sum, i) => sum.plus(new Decimal(i.price).mul(i.quantity)),
    new Decimal(0),
  );

  const discount = couponDiscount.greaterThan(subtotal) ? subtotal : couponDiscount;
  const total = subtotal.minus(discount);

  const orderItems = pricedItems.map((i) => ({
    itemId: i.itemId,
    itemName: i.name,
    itemPrice: i.price,
    quantity: i.quantity,
  }));

  return { orderItems, subtotal, discount, total };
}
