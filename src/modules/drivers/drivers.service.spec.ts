import { Test, TestingModule } from '@nestjs/testing';
import { DriversService } from './drivers.service';
import { PrismaService } from '@shared/database/prisma.service';
import { ConflictException, ForbiddenException, NotFoundException, BadRequestException } from '@nestjs/common';

// ---------------------------------------------------------------------------
// Minimal Prisma mock factory
// ---------------------------------------------------------------------------
interface MockOrder {
  id: string; status: string; fulfillment: string; deliveryAddress: string | null;
  notes: string | null; driverId: string | null; createdAt: Date;
  store: object; customer: object;
}

interface MockPrisma {
  order: {
    findMany: jest.Mock;
    findFirst: jest.Mock;
    findUnique: jest.Mock;
    updateMany: jest.Mock;
    update: jest.Mock;
  };
  auditLog: { create: jest.Mock };
  $transaction: jest.Mock;
}

const makePrisma = (): MockPrisma => ({
  order: {
    findMany: jest.fn(),
    findFirst: jest.fn(),
    findUnique: jest.fn(),
    updateMany: jest.fn(),
    update: jest.fn(),
  },
  auditLog: { create: jest.fn().mockResolvedValue({}) },
  $transaction: jest.fn().mockImplementation(async (ops: unknown[]) =>
    Promise.all((ops as Promise<unknown>[]).map((op) => op)),
  ),
});

let mockPrisma: MockPrisma;

const DRIVER_ID = 'driver-001';
const ORDER_ID  = 'order-001';

const baseOrder = {
  id: ORDER_ID,
  status: 'READY',
  fulfillment: 'DELIVERY',
  deliveryAddress: 'Villa 12, Riyadh',
  notes: null,
  driverId: null,
  createdAt: new Date(),
  store: { id: 's1', name: 'Store A', address: 'Addr', phone: '+9661' },
  customer: { phone: '+966501234567' },
};

// ---------------------------------------------------------------------------

describe('DriversService', () => {
  let service: DriversService;

  beforeEach(async () => {
    mockPrisma = makePrisma();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DriversService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<DriversService>(DriversService);
  });

  afterEach(() => jest.clearAllMocks());

  // -------------------------------------------------------------------------
  // getAvailableOrders
  // -------------------------------------------------------------------------
  describe('getAvailableOrders()', () => {
    it('returns READY DELIVERY orders with no driver', async () => {
      mockPrisma.order.findMany.mockResolvedValue([baseOrder]);
      const result = await service.getAvailableOrders();
      expect(result).toHaveLength(1);
      expect(mockPrisma.order.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { status: 'READY', fulfillment: 'DELIVERY', driverId: null },
        }),
      );
    });

    it('returns empty array when no orders are available', async () => {
      mockPrisma.order.findMany.mockResolvedValue([]);
      const result = await service.getAvailableOrders();
      expect(result).toEqual([]);
    });
  });

  // -------------------------------------------------------------------------
  // getActiveOrder
  // -------------------------------------------------------------------------
  describe('getActiveOrder()', () => {
    it('returns the drivers in-progress order', async () => {
      const active = { ...baseOrder, status: 'OUT_FOR_DELIVERY', driverId: DRIVER_ID };
      mockPrisma.order.findFirst.mockResolvedValue(active);
      const result = await service.getActiveOrder(DRIVER_ID);
      expect(result).toMatchObject({ status: 'OUT_FOR_DELIVERY' });
    });

    it('returns null when driver has no active order', async () => {
      mockPrisma.order.findFirst.mockResolvedValue(null);
      const result = await service.getActiveOrder(DRIVER_ID);
      expect(result).toBeNull();
    });
  });

  // -------------------------------------------------------------------------
  // acceptOrder
  // -------------------------------------------------------------------------
  describe('acceptOrder()', () => {
    it('claims an available order and sets status to OUT_FOR_DELIVERY', async () => {
      mockPrisma.order.findFirst.mockResolvedValue(null); // no active order
      mockPrisma.order.updateMany.mockResolvedValue({ count: 1 });
      mockPrisma.order.findUnique.mockResolvedValue({
        ...baseOrder, status: 'OUT_FOR_DELIVERY', driverId: DRIVER_ID,
      });

      const result = await service.acceptOrder(ORDER_ID, DRIVER_ID);
      expect(mockPrisma.order.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: ORDER_ID, status: 'READY', fulfillment: 'DELIVERY', driverId: null },
          data: { driverId: DRIVER_ID, status: 'OUT_FOR_DELIVERY' },
        }),
      );
      expect(result).toMatchObject({ status: 'OUT_FOR_DELIVERY', driverId: DRIVER_ID });
    });

    it('throws DRIVER_BUSY if driver already has an active order', async () => {
      mockPrisma.order.findFirst.mockResolvedValue({ id: 'other-order' }); // active exists
      await expect(service.acceptOrder(ORDER_ID, DRIVER_ID))
        .rejects.toThrow(ConflictException);
    });

    it('throws NotFoundException when order does not exist', async () => {
      mockPrisma.order.findFirst.mockResolvedValue(null);
      mockPrisma.order.updateMany.mockResolvedValue({ count: 0 });
      mockPrisma.order.findUnique.mockResolvedValue(null); // order not found
      await expect(service.acceptOrder(ORDER_ID, DRIVER_ID))
        .rejects.toThrow(NotFoundException);
    });

    it('throws ORDER_UNAVAILABLE when order was claimed by another driver', async () => {
      mockPrisma.order.findFirst.mockResolvedValue(null);
      mockPrisma.order.updateMany.mockResolvedValue({ count: 0 });
      mockPrisma.order.findUnique.mockResolvedValue({ id: ORDER_ID, status: 'OUT_FOR_DELIVERY', fulfillment: 'DELIVERY' });
      await expect(service.acceptOrder(ORDER_ID, DRIVER_ID))
        .rejects.toThrow(ConflictException);
    });

    it('throws NOT_DELIVERY when order is a PICKUP order', async () => {
      mockPrisma.order.findFirst.mockResolvedValue(null);
      mockPrisma.order.updateMany.mockResolvedValue({ count: 0 });
      mockPrisma.order.findUnique.mockResolvedValue({ id: ORDER_ID, status: 'READY', fulfillment: 'PICKUP' });
      await expect(service.acceptOrder(ORDER_ID, DRIVER_ID))
        .rejects.toThrow(BadRequestException);
    });
  });

  // -------------------------------------------------------------------------
  // updateStatus
  // -------------------------------------------------------------------------
  describe('updateStatus()', () => {
    it('transitions OUT_FOR_DELIVERY → DELIVERED successfully', async () => {
      mockPrisma.order.findUnique.mockResolvedValue({
        id: ORDER_ID, driverId: DRIVER_ID, status: 'OUT_FOR_DELIVERY',
      });
      const delivered = { ...baseOrder, status: 'DELIVERED', driverId: DRIVER_ID };
      mockPrisma.$transaction.mockResolvedValue([delivered, {}]);

      const result = await service.updateStatus(ORDER_ID, { status: 'DELIVERED' }, DRIVER_ID);
      expect(result).toMatchObject({ status: 'DELIVERED' });
    });

    it('throws ForbiddenException if order is assigned to a different driver', async () => {
      mockPrisma.order.findUnique.mockResolvedValue({
        id: ORDER_ID, driverId: 'other-driver', status: 'OUT_FOR_DELIVERY',
      });
      await expect(service.updateStatus(ORDER_ID, { status: 'DELIVERED' }, DRIVER_ID))
        .rejects.toThrow(ForbiddenException);
    });

    it('throws NotFoundException when order does not exist', async () => {
      mockPrisma.order.findUnique.mockResolvedValue(null);
      await expect(service.updateStatus(ORDER_ID, { status: 'DELIVERED' }, DRIVER_ID))
        .rejects.toThrow(NotFoundException);
    });

    it('throws BadRequestException for an invalid status transition', async () => {
      mockPrisma.order.findUnique.mockResolvedValue({
        id: ORDER_ID, driverId: DRIVER_ID, status: 'DELIVERED', // already done
      });
      await expect(service.updateStatus(ORDER_ID, { status: 'DELIVERED' }, DRIVER_ID))
        .rejects.toThrow(BadRequestException);
    });
  });
});