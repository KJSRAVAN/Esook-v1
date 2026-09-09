import {
  Controller, Get, Post, Patch, Param, Body,
  UseGuards, HttpCode, HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { StoresService } from './stores.service';
import { createStoreSchema, updateStoreSchema } from './stores.schemas';
import { ZodValidationPipe } from '@shared/pipes/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/guards/roles.decorator';

@ApiTags('stores')
@Controller('stores')
export class StoresController {
  constructor(private readonly stores: StoresService) {}

  @ApiOperation({ summary: 'List all active stores (public)' })
  @Get()
  getAll() { return this.stores.getAll(); }

  @ApiOperation({ summary: 'List all areas (public)' })
  @Get('areas')
  getAreas() { return this.stores.getAreas(); }

  @ApiOperation({ summary: 'Get store by ID (public)' })
  @Get(':storeId')
  getById(@Param('storeId') storeId: string) {
    return this.stores.getById(storeId);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create store (SUPER_ADMIN)' })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body(new ZodValidationPipe(createStoreSchema)) body: unknown) {
    return this.stores.create(body as CreateStoreDto);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update store (SUPER_ADMIN)' })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @Patch(':storeId')
  update(
    @Param('storeId') storeId: string,
    @Body(new ZodValidationPipe(updateStoreSchema)) body: unknown,
  ) {
    return this.stores.update(storeId, body as UpdateStoreDto);
  }
}

// type aliases for controller body typing
import { CreateStoreDto, UpdateStoreDto } from './stores.schemas';
