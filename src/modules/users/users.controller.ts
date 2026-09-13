import { Controller, Get, Patch, Body, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody, ApiQuery } from '@nestjs/swagger';
import { Request } from 'express';
import { UsersService } from './users.service';
import { updateProfileSchema, userQuerySchema, UpdateProfileDto, UserQueryDto } from './users.schemas';
import { ZodValidationPipe } from '@shared/pipes/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/guards/roles.decorator';

type AuthReq = Request & { user: { id: string } };

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @ApiOperation({ summary: 'Get my profile' })
  @Get('me')
  getProfile(@Req() req: AuthReq) {
    return this.users.getProfile(req.user.id);
  }

  @ApiOperation({ summary: 'Update my profile' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        name:  { type: 'string', example: 'Ahmed Ali' },
        email: { type: 'string', example: 'ahmed@example.com' },
      },
    },
  })
  @Patch('me')
  updateProfile(
    @Req() req: AuthReq,
    @Body(new ZodValidationPipe(updateProfileSchema)) body: UpdateProfileDto,
  ) {
    return this.users.updateProfile(req.user.id, body);
  }

  @ApiOperation({ summary: 'List all users with pagination (SUPER_ADMIN)' })
  @ApiQuery({ name: 'page',  required: false, type: Number, example: 1 })
  @ApiQuery({ name: 'limit', required: false, type: Number, example: 50 })
  @ApiQuery({ name: 'role',  required: false, enum: ['CUSTOMER', 'STAFF', 'MANAGER', 'SUPER_ADMIN'] })
  @UseGuards(RolesGuard)
  @Roles('SUPER_ADMIN')
  @Get()
  listAll(@Query(new ZodValidationPipe(userQuerySchema)) query: UserQueryDto) {
    return this.users.listAll(query);
  }
}

