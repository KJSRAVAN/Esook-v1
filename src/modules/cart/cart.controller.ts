import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
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

  @ApiOperation({ summary: 'Get current cart' })
  @Get()
  get(@Req() req: AuthReq) {
    return this.cart.getCart(req.user.id);
  }

  @ApiOperation({ summary: 'Add item to cart' })
  @Post('items')
  add(
    @Body(new ZodValidationPipe(addToCartSchema)) body: { itemId: string; quantity: number },
    @Req() req: AuthReq,
  ) {
    return this.cart.addItem(req.user.id, body.itemId, body.quantity);
  }

  @ApiOperation({ summary: 'Update item quantity (0 = remove)' })
  @Patch('items/:itemId')
  update(
    @Param('itemId') itemId: string,
    @Body(new ZodValidationPipe(updateCartItemSchema)) body: { quantity: number },
    @Req() req: AuthReq,
  ) {
    return this.cart.updateItem(req.user.id, itemId, body.quantity);
  }

  @ApiOperation({ summary: 'Clear cart' })
  @Delete()
  async clear(@Req() req: AuthReq) {
    await this.cart.clearCart(req.user.id);
    return { message: 'Cart cleared' };
  }
}
