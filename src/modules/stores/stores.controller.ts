import {
  Controller, Get, Post, Patch, Param, Body,
  UseGuards, HttpCode, HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody } from '@nestjs/swagger';
import { StoresService } from './stores.service';
import { createStoreSchema, updateStoreSchema, CreateStoreDto, UpdateStoreDto } from './stores.schemas';
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

  @ApiOperation({ summary: 'List all delivery areas (public)' })
  @Get('areas')
  getAreas() { return this.stores.getAreas(); }

  @ApiOperation({ summary: 'Get a store by ID (public)' })
  @Get(':storeId')
  getById(@Param('storeId') storeId: string) {
    return this.stores.getById(storeId);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a new store (SUPER_ADMIN)' })
  @ApiBody({
    schema: {
      type: 'object', required: ['name', 'areaId'],
      properties: {
        name:    { type: 'string', example: 'Esook Riyadh Central' },
        areaId:  { type: 'string', example: 'clx...' },
        address: { type: 'string', example: 'King Fahd Road, Riyadh' },
        phone:   { type: 'string', example: '+966112345678' },
      },
    },
  })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body(new ZodValidationPipe(createStoreSchema)) body: CreateStoreDto) {
    return this.stores.create(body);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update a store (SUPER_ADMIN)' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        name:     { type: 'string', example: 'Esook Riyadh North' },
        address:  { type: 'string', example: 'Olaya Street, Riyadh' },
        phone:    { type: 'string', example: '+966112345679' },
        isActive: { type: 'boolean', example: true },
      },
    },
  })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @Patch(':storeId')
  update(
    @Param('storeId') storeId: string,
    @Body(new ZodValidationPipe(updateStoreSchema)) body: UpdateStoreDto,
  ) {
    return this.stores.update(storeId, body);
  }
}