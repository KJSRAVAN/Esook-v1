import { Controller, Get, Post, Patch, Param, Body, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody } from '@nestjs/swagger';
import { Request } from 'express';
import { DriversService } from './drivers.service';
import { driverStatusSchema, DriverStatusDto } from './drivers.schemas';
import { ZodValidationPipe } from '@shared/pipes/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/guards/roles.decorator';

type DriverReq = Request & { user: { id: string; role: string } };

@ApiTags('drivers')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('DRIVER')
@Controller('drivers')
export class DriversController {
  constructor(private readonly drivers: DriversService) {}

  @ApiOperation({ summary: 'List available DELIVERY orders ready for pickup (DRIVER)' })
  @Get('orders/available')
  getAvailable() {
    return this.drivers.getAvailableOrders();
  }

  @ApiOperation({ summary: 'Get my currently active in-progress order (DRIVER)' })
  @Get('orders/active')
  getActive(@Req() req: DriverReq) {
    return this.drivers.getActiveOrder(req.user.id);
  }

  @ApiOperation({ summary: 'Accept (self-assign) an available order (DRIVER)' })
  @Post('orders/:orderId/accept')
  accept(@Param('orderId') orderId: string, @Req() req: DriverReq) {
    return this.drivers.acceptOrder(orderId, req.user.id);
  }

  @ApiOperation({ summary: 'Update delivery status: OUT_FOR_DELIVERY → DELIVERED (DRIVER)' })
  @ApiBody({
    schema: {
      type: 'object', required: ['status'],
      properties: {
        status: {
          type: 'string',
          enum: ['DELIVERED'],
          example: 'DELIVERED',
          description: 'Only DELIVERED is valid here — OUT_FOR_DELIVERY is set automatically on accept',
        },
      },
    },
  })
  @Patch('orders/:orderId/status')
  updateStatus(
    @Param('orderId') orderId: string,
    @Body(new ZodValidationPipe(driverStatusSchema)) body: DriverStatusDto,
    @Req() req: DriverReq,
  ) {
    return this.drivers.updateStatus(orderId, body, req.user.id);
  }
}