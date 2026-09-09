import {
  Controller, Get, Post, Patch, Param, Body,
  Query, UseGuards, Req, Headers, HttpCode, HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
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

  @ApiOperation({ summary: 'Place order (customer). Send X-Idempotency-Key header.' })
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
  @Get('my')
  getMyOrders(
    @Req() req: AuthReq,
    @Query(new ZodValidationPipe(orderQuerySchema)) query: OrderQueryDto,
  ) {
    return this.orders.getMyOrders(req.user.id, query);
  }

  @ApiOperation({ summary: 'List store orders (STAFF+)' })
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

  @ApiOperation({ summary: 'Get single order' })
  @Get(':orderId')
  getById(@Param('orderId') orderId: string, @Req() req: AuthReq) {
    return this.orders.getOrderById(orderId, req.user);
  }

  @ApiOperation({ summary: 'Update order status (STAFF+)' })
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
