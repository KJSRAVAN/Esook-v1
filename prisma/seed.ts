import { PrismaClient, Role, DiscountType } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  console.log('🌱 Starting seed...');

  // ---------------------------------------------------------------------------
  // Areas
  // ---------------------------------------------------------------------------
  const riyadh = await prisma.area.upsert({
    where: { name: 'Riyadh' },
    update: {},
    create: { name: 'Riyadh' },
  });

  const jeddah = await prisma.area.upsert({
    where: { name: 'Jeddah' },
    update: {},
    create: { name: 'Jeddah' },
  });

  // ---------------------------------------------------------------------------
  // Stores
  // ---------------------------------------------------------------------------
  const freshMart = await upsertStore('Fresh Mart Riyadh', riyadh.id, 'King Fahd Road, Riyadh');
  const greenBasket = await upsertStore('Green Basket Jeddah', jeddah.id, 'Tahlia Street, Jeddah');

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------
  const fmDairy = await upsertCategory(freshMart.id, 'Dairy & Eggs', 1);
  const fmBakery = await upsertCategory(freshMart.id, 'Bakery', 2);
  const fmMeat = await upsertCategory(freshMart.id, 'Meat & Poultry', 3);
  const gbProduce = await upsertCategory(greenBasket.id, 'Fresh Produce', 1);
  const gbBeverages = await upsertCategory(greenBasket.id, 'Beverages', 2);

  // ---------------------------------------------------------------------------
  // Items
  // ---------------------------------------------------------------------------
  await upsertItem(freshMart.id, fmDairy.id, 'Whole Milk 1L', 5.5);
  await upsertItem(freshMart.id, fmDairy.id, 'Free Range Eggs 12pk', 18.0);
  await upsertItem(freshMart.id, fmBakery.id, 'Sourdough Bread', 12.0);
  await upsertItem(freshMart.id, fmMeat.id, 'Chicken Breast 500g', 22.0);
  await upsertItem(freshMart.id, fmMeat.id, 'Basmati Rice 2kg', 15.0);
  await upsertItem(greenBasket.id, gbProduce.id, 'Organic Tomatoes 1kg', 9.0);
  await upsertItem(greenBasket.id, gbProduce.id, 'Avocado x3', 14.0);
  await upsertItem(greenBasket.id, gbBeverages.id, 'Fresh Orange Juice 1L', 11.0);
  await upsertItem(greenBasket.id, gbBeverages.id, 'Greek Yogurt 500g', 16.0);

  // ---------------------------------------------------------------------------
  // Staff users  (email + argon2 password, no OTP)
  // ---------------------------------------------------------------------------
  const superAdminHash = await argon2.hash('Admin@1234');
  await prisma.user.upsert({
    where: { email: 'admin@esook.store' },
    update: {},
    create: {
      name: 'Super Admin',
      email: 'admin@esook.store',
      passwordHash: superAdminHash,
      role: Role.SUPER_ADMIN,
    },
  });

  const managerHash = await argon2.hash('Manager@1234');
  await prisma.user.upsert({
    where: { email: 'manager.riyadh@esook.store' },
    update: {},
    create: {
      name: 'Manager Riyadh',
      email: 'manager.riyadh@esook.store',
      passwordHash: managerHash,
      role: Role.MANAGER,
      storeId: freshMart.id,
    },
  });
  await prisma.user.upsert({
    where: { email: 'manager.jeddah@esook.store' },
    update: {},
    create: {
      name: 'Manager Jeddah',
      email: 'manager.jeddah@esook.store',
      passwordHash: managerHash,
      role: Role.MANAGER,
      storeId: greenBasket.id,
    },
  });

  const staffHash = await argon2.hash('Staff@1234');
  await prisma.user.upsert({
    where: { email: 'staff.riyadh@esook.store' },
    update: {},
    create: {
      name: 'Staff Riyadh',
      email: 'staff.riyadh@esook.store',
      passwordHash: staffHash,
      role: Role.STAFF,
      storeId: freshMart.id,
    },
  });

  // ---------------------------------------------------------------------------
  // Coupons
  // ---------------------------------------------------------------------------
  await upsertCoupon('WELCOME10', DiscountType.PERCENT, 10, 50, 500);
  await upsertCoupon('FLAT20', DiscountType.FLAT, 20, 100, null);

  console.log('✅ Seed completed');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function upsertStore(name: string, areaId: string, address?: string) {
  return prisma.store.upsert({
    where: { id: `store-${name.toLowerCase().replace(/\s+/g, '-')}` },
    update: {},
    create: { id: `store-${name.toLowerCase().replace(/\s+/g, '-')}`, name, areaId, address },
  });
}

async function upsertCategory(storeId: string, name: string, sortOrder: number) {
  return prisma.category.upsert({
    where: { storeId_name: { storeId, name } },
    update: { sortOrder },
    create: { storeId, name, sortOrder },
  });
}

async function upsertItem(storeId: string, categoryId: string, name: string, price: number) {
  const existing = await prisma.item.findFirst({ where: { storeId, name } });
  if (!existing) {
    await prisma.item.create({ data: { storeId, categoryId, name, price } });
  }
}

async function upsertCoupon(
  code: string,
  discountType: DiscountType,
  discountValue: number,
  minOrderValue: number | null,
  maxUses: number | null,
) {
  await prisma.coupon.upsert({
    where: { code },
    update: {},
    create: { code, discountType, discountValue, minOrderValue, maxUses, isActive: true },
  });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
