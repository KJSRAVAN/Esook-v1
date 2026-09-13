import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody } from '@nestjs/swagger';
import { Request } from 'express';
import { CartService } from './cart.service';
import { addToCartSchema, updateCartItemSchema } from './cart.schemas';
import { ZodValidationPipe } from '@shared/pipes/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

type AuthReq = Request & { user: { id: string } };

@ApiTags('cart')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('cart')
export class CartController {
  constructor(private readonly cart: CartService) {}

  @ApiOperation({ summary: 'Get current cart (returns empty cart if Redis is down)' })
  @Get()
  get(@Req() req: AuthReq) {
    return this.cart.getCart(req.user.id);
  }

  @ApiOperation({ summary: 'Add item to cart — enforces single-store rule' })
  @ApiBody({
    schema: {
      type: 'object', required: ['itemId', 'quantity'],
      properties: {
        itemId:   { type: 'string', example: 'clx...' },
        quantity: { type: 'integer', example: 2, minimum: 1, maximum: 99 },
      },
    },
  })
  @Post('items')
  add(
    @Body(new ZodValidationPipe(addToCartSchema)) body: { itemId: string; quantity: number },
    @Req() req: AuthReq,
  ) {
    return this.cart.addItem(req.user.id, body.itemId, body.quantity);
  }

  @ApiOperation({ summary: 'Update item quantity. Set quantity to 0 to remove the item.' })
  @ApiBody({
    schema: {
      type: 'object', required: ['quantity'],
      properties: {
        quantity: { type: 'integer', example: 3, minimum: 0, maximum: 99 },
      },
    },
  })
  @Patch('items/:itemId')
  update(
    @Param('itemId') itemId: string,
    @Body(new ZodValidationPipe(updateCartItemSchema)) body: { quantity: number },
    @Req() req: AuthReq,
  ) {
    return this.cart.updateItem(req.user.id, itemId, body.quantity);
  }

  @ApiOperation({ summary: 'Clear entire cart' })
  @Delete()
  async clear(@Req() req: AuthReq) {
    await this.cart.clearCart(req.user.id);
    return { message: 'Cart cleared' };
  }
}