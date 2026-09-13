import {
  Controller, Get, Post, Patch, Param, Body,
  Query, UseGuards, Req, Headers, HttpCode, HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody, ApiHeader, ApiQuery } from '@nestjs/swagger';
import { Request } from 'express';
import { OrdersService } from './orders.service';
import {
  createOrderSchema, updateOrderStatusSchema, orderQuerySchema,
  CreateOrderDto, UpdateOrderStatusDto, OrderQueryDto,
} from './orders.schemas';
import { ZodValidationPipe } from '@shared/pipes/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/guards/roles.decorator';

type AuthReq = Request & { user: { id: string; role: string; storeId: string | null } };

@ApiTags('orders')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @ApiOperation({ summary: 'Place an order (customer). Include X-Idempotency-Key header to prevent duplicates on retry.' })
  @ApiHeader({
    name: 'X-Idempotency-Key',
    description: 'Unique key per order attempt (UUID). Re-sending the same key returns the existing order.',
    required: false,
    example: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
  })
  @ApiBody({
    schema: {
      type: 'object', required: ['storeId', 'fulfillment', 'items'],
      properties: {
        storeId:         { type: 'string', example: 'clx...' },
        fulfillment:     { type: 'string', enum: ['PICKUP', 'DELIVERY'] },
        deliveryAddress: { type: 'string', example: 'Villa 12, Riyadh', description: 'Required when fulfillment is DELIVERY' },
        couponCode:      { type: 'string', example: 'SAVE20' },
        notes:           { type: 'string', example: 'No ice please' },
        items: {
          type: 'array',
          items: {
            type: 'object', required: ['itemId', 'quantity'],
            properties: {
              itemId:   { type: 'string', example: 'clx...' },
              quantity: { type: 'integer', example: 2, minimum: 1, maximum: 99 },
            },
          },
        },
      },
    },
  })
  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(
    @Body(new ZodValidationPipe(createOrderSchema)) body: CreateOrderDto,
    @Req() req: AuthReq,
    @Headers('x-idempotency-key') idempotencyKey?: string,
  ) {
    return this.orders.createOrder(body, req.user.id, idempotencyKey);
  }

  @ApiOperation({ summary: 'List my orders (customer)' })
  @ApiQuery({ name: 'page',   required: false, type: Number, example: 1 })
  @ApiQuery({ name: 'limit',  required: false, type: Number, example: 20 })
  @ApiQuery({ name: 'status', required: false, enum: ['PENDING','ACCEPTED','REJECTED','PREPARING','READY','OUT_FOR_DELIVERY','DELIVERED','CANCELLED'] })
  @Get('my')
  getMyOrders(
    @Req() req: AuthReq,
    @Query(new ZodValidationPipe(orderQuerySchema)) query: OrderQueryDto,
  ) {
    return this.orders.getMyOrders(req.user.id, query);
  }

  @ApiOperation({ summary: 'List all orders for a store (STAFF+)' })
  @ApiQuery({ name: 'page',   required: false, type: Number, example: 1 })
  @ApiQuery({ name: 'limit',  required: false, type: Number, example: 20 })
  @ApiQuery({ name: 'status', required: false, enum: ['PENDING','ACCEPTED','REJECTED','PREPARING','READY','OUT_FOR_DELIVERY','DELIVERED','CANCELLED'] })
  @UseGuards(RolesGuard)
  @Roles('STAFF', 'MANAGER', 'SUPER_ADMIN')
  @Get('store/:storeId')
  getStoreOrders(
    @Param('storeId') storeId: string,
    @Query(new ZodValidationPipe(orderQuerySchema)) query: OrderQueryDto,
    @Req() req: AuthReq,
  ) {
    return this.orders.getStoreOrders(storeId, query, req.user);
  }

  @ApiOperation({ summary: 'Get a single order by ID' })
  @Get(':orderId')
  getById(@Param('orderId') orderId: string, @Req() req: AuthReq) {
    return this.orders.getOrderById(orderId, req.user);
  }

  @ApiOperation({ summary: 'Update order status (STAFF+)' })
  @ApiBody({
    schema: {
      type: 'object', required: ['status'],
      properties: {
        status: {
          type: 'string',
          enum: ['ACCEPTED','REJECTED','PREPARING','READY','OUT_FOR_DELIVERY','DELIVERED','CANCELLED'],
          example: 'ACCEPTED',
        },
        rejectedReason: { type: 'string', example: 'Item out of stock', description: 'Required when status is REJECTED' },
      },
    },
  })
  @UseGuards(RolesGuard)
  @Roles('STAFF', 'MANAGER', 'SUPER_ADMIN')
  @Patch(':orderId/status')
  updateStatus(
    @Param('orderId') orderId: string,
    @Body(new ZodValidationPipe(updateOrderStatusSchema)) body: UpdateOrderStatusDto,
    @Req() req: AuthReq,
  ) {
    return this.orders.updateStatus(orderId, body, req.user);
  }
}