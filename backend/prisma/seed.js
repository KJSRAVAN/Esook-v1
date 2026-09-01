import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function getOrCreateStore(name, areaId) {
  let store = await prisma.store.findFirst({ where: { name } });
  if (!store) {
    store = await prisma.store.create({ data: { name, areaId } });
  }
  return store;
}

async function getOrCreateCoupon(code, data) {
  let coupon = await prisma.coupon.findUnique({ where: { code } });
  if (!coupon) {
    coupon = await prisma.coupon.create({ data });
  }
  return coupon;
}

async function getOrCreateItem(name, storeId, data) {
  let item = await prisma.item.findFirst({ where: { name, storeId } });
  if (!item) {
    item = await prisma.item.create({ data: { name, storeId, ...data } });
  }
  return item;
}

async function main() {
  console.log('Starting seed...');

  // 1. Areas
  const marina = await prisma.area.upsert({
    where: { name: 'Dubai Marina' },
    update: {},
    create: { name: 'Dubai Marina' }
  });
  
  const downtown = await prisma.area.upsert({
    where: { name: 'Downtown Dubai' },
    update: {},
    create: { name: 'Downtown Dubai' }
  });

  // 2. Stores
  const freshMart = await getOrCreateStore('Fresh Mart Marina', marina.id);
  const greenBasket = await getOrCreateStore('Green Basket Downtown', downtown.id);

  // 3. Items for Fresh Mart Marina
  await getOrCreateItem('Whole Milk 1L', freshMart.id, { price: 5.50 });
  await getOrCreateItem('Free Range Eggs 12pk', freshMart.id, { price: 18.00 });
  await getOrCreateItem('Sourdough Bread', freshMart.id, { price: 12.00 });
  await getOrCreateItem('Chicken Breast 500g', freshMart.id, { price: 22.00 });
  await getOrCreateItem('Basmati Rice 2kg', freshMart.id, { price: 15.00 });

  // 4. Items for Green Basket Downtown
  await getOrCreateItem('Organic Tomatoes 1kg', greenBasket.id, { price: 9.00 });
  await getOrCreateItem('Avocado x3', greenBasket.id, { price: 14.00 });
  await getOrCreateItem('Fresh Orange Juice 1L', greenBasket.id, { price: 11.00 });
  await getOrCreateItem('Greek Yogurt 500g', greenBasket.id, { price: 16.00 });
  await getOrCreateItem('Dark Chocolate 100g', greenBasket.id, { price: 13.00 });

  // 5. Users
  const adminPassword = await bcrypt.hash('Admin@1234', 12);
  await prisma.user.upsert({
    where: { email: 'admin@esook.ae' },
    update: {},
    create: { name: 'Super Admin', email: 'admin@esook.ae', passwordHash: adminPassword, role: 'SUPER_ADMIN' }
  });

  const managerPassword = await bcrypt.hash('Manager@1234', 12);
  await prisma.user.upsert({
    where: { email: 'manager.marina@esook.ae' },
    update: {},
    create: { name: 'Manager Marina', email: 'manager.marina@esook.ae', passwordHash: managerPassword, role: 'MANAGER', storeId: freshMart.id }
  });
  await prisma.user.upsert({
    where: { email: 'manager.downtown@esook.ae' },
    update: {},
    create: { name: 'Manager Downtown', email: 'manager.downtown@esook.ae', passwordHash: managerPassword, role: 'MANAGER', storeId: greenBasket.id }
  });

  const staffPassword = await bcrypt.hash('Staff@1234', 12);
  await prisma.user.upsert({
    where: { email: 'staff.marina@esook.ae' },
    update: {},
    create: { name: 'Staff Marina', email: 'staff.marina@esook.ae', passwordHash: staffPassword, role: 'STAFF', storeId: freshMart.id }
  });
  await prisma.user.upsert({
    where: { email: 'staff.downtown@esook.ae' },
    update: {},
    create: { name: 'Staff Downtown', email: 'staff.downtown@esook.ae', passwordHash: staffPassword, role: 'STAFF', storeId: greenBasket.id }
  });

  const customerPassword = await bcrypt.hash('Customer@1234', 12);
  await prisma.user.upsert({
    where: { email: 'ahmed@example.ae' },
    update: {},
    create: { name: 'Ahmed Al Rashidi', email: 'ahmed@example.ae', phone: '+971501234567', passwordHash: customerPassword, role: 'CUSTOMER' }
  });

  // 6. Coupons
  await getOrCreateCoupon('SAVE10', {
    code: 'SAVE10', discountType: 'PERCENT', discountValue: 10, minOrderValue: 50, maxUses: 100, isActive: true
  });
  await getOrCreateCoupon('FLAT20', {
    code: 'FLAT20', discountType: 'FLAT', discountValue: 20, minOrderValue: 100, isActive: true
  });

  console.log('Seed completed successfully.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
