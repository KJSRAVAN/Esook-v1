import {
  Controller, Get, Post, Patch, Delete, Param,
  Body, Query, UseGuards, HttpCode, HttpStatus, Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody, ApiQuery } from '@nestjs/swagger';
import { Request } from 'express';
import { CatalogService } from './catalog.service';
import {
  createItemSchema, updateItemSchema, createCategorySchema, catalogQuerySchema,
  CreateItemDto, UpdateItemDto, CreateCategoryDto, CatalogQueryDto,
} from './catalog.schemas';
import { ZodValidationPipe } from '@shared/pipes/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/guards/roles.decorator';

type StoreReq = Request & { user: { id: string; role: string; storeId: string | null } };

@ApiTags('catalog')
@Controller('stores/:storeId')
export class CatalogController {
  constructor(private readonly catalog: CatalogService) {}

  // ---- Public read endpoints ----

  @ApiOperation({ summary: 'List items for a store (public)' })
  @ApiQuery({ name: 'page',       required: false, type: Number, example: 1 })
  @ApiQuery({ name: 'limit',      required: false, type: Number, example: 50 })
  @ApiQuery({ name: 'categoryId', required: false, type: String })
  @ApiQuery({ name: 'search',     required: false, type: String })
  @ApiQuery({ name: 'available',  required: false, enum: ['true', 'false'] })
  @Get('items')
  getItems(
    @Param('storeId') storeId: string,
    @Query(new ZodValidationPipe(catalogQuerySchema)) query: CatalogQueryDto,
  ) {
    return this.catalog.getItems(storeId, query);
  }

  @ApiOperation({ summary: 'Get a single item by ID (public)' })
  @Get('items/:itemId')
  getItem(@Param('itemId') itemId: string) {
    return this.catalog.getItemById(itemId);
  }

  @ApiOperation({ summary: 'List categories for a store (public)' })
  @Get('categories')
  getCategories(@Param('storeId') storeId: string) {
    return this.catalog.getCategories(storeId);
  }

  // ---- Staff write endpoints ----

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create item (MANAGER+)' })
  @ApiBody({
    schema: {
      type: 'object', required: ['name', 'price'],
      properties: {
        name:        { type: 'string', example: 'Mango Juice 1L' },
        description: { type: 'string', example: 'Fresh mango juice, chilled' },
        price:       { type: 'number', example: 12.50 },
        categoryId:  { type: 'string', example: 'clx...' },
        imageUrl:    { type: 'string', example: 'https://cdn.example.com/mango.jpg' },
        sortOrder:   { type: 'integer', example: 0 },
      },
    },
  })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('MANAGER', 'SUPER_ADMIN')
  @Post('items')
  @HttpCode(HttpStatus.CREATED)
  createItem(
    @Param('storeId') storeId: string,
    @Body(new ZodValidationPipe(createItemSchema)) body: CreateItemDto,
    @Req() req: StoreReq,
  ) {
    return this.catalog.createItem(storeId, body, req.user);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update item or toggle availability (MANAGER+)' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        name:        { type: 'string', example: 'Mango Juice 1.5L' },
        price:       { type: 'number', example: 15.00 },
        isAvailable: { type: 'boolean', example: false, description: 'Set false to hide from storefront' },
        sortOrder:   { type: 'integer', example: 1 },
      },
    },
  })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('MANAGER', 'SUPER_ADMIN')
  @Patch('items/:itemId')
  updateItem(
    @Param('itemId') itemId: string,
    @Body(new ZodValidationPipe(updateItemSchema)) body: UpdateItemDto,
    @Req() req: StoreReq,
  ) {
    return this.catalog.updateItem(itemId, body, req.user);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete item permanently (SUPER_ADMIN)' })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @Delete('items/:itemId')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteItem(@Param('itemId') itemId: string, @Req() req: StoreReq) {
    await this.catalog.deleteItem(itemId, req.user);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create category (MANAGER+)' })
  @ApiBody({
    schema: {
      type: 'object', required: ['name'],
      properties: {
        name:      { type: 'string', example: 'Beverages' },
        sortOrder: { type: 'integer', example: 0 },
      },
    },
  })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('MANAGER', 'SUPER_ADMIN')
  @Post('categories')
  @HttpCode(HttpStatus.CREATED)
  createCategory(
    @Param('storeId') storeId: string,
    @Body(new ZodValidationPipe(createCategorySchema)) body: CreateCategoryDto,
    @Req() req: StoreReq,
  ) {
    return this.catalog.createCategory(storeId, body, req.user);
  }
}