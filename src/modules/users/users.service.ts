import { Injectable } from '@nestjs/common';
import { PrismaService } from '@shared/database/prisma.service';
import { Prisma } from '@prisma/client';
import { UpdateProfileDto, UserQueryDto } from './users.schemas';

const SAFE_USER_SELECT = {
  id: true, name: true, email: true, phone: true, role: true,
  storeId: true, isPhoneVerified: true, isActive: true,
  createdAt: true, updatedAt: true,
} satisfies Prisma.UserSelect;

export type SafeUser = Prisma.UserGetPayload<{ select: typeof SAFE_USER_SELECT }>;

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getProfile(userId: string): Promise<SafeUser | null> {
    return this.prisma.user.findUnique({ where: { id: userId }, select: SAFE_USER_SELECT });
  }

  updateProfile(userId: string, dto: UpdateProfileDto): Promise<SafeUser> {
    return this.prisma.user.update({
      where: { id: userId },
      data: dto,
      select: SAFE_USER_SELECT,
    });
  }

  async listAll(query: UserQueryDto): Promise<{ data: SafeUser[]; total: number; page: number; limit: number }> {
    const skip = (query.page - 1) * query.limit;
    const where = query.role ? { role: query.role } : {};

    const [data, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where,
        select: SAFE_USER_SELECT,
        orderBy: { createdAt: 'desc' },
        skip,
        take: query.limit,
      }),
      this.prisma.user.count({ where }),
    ]);

    return { data, total, page: query.page, limit: query.limit };
  }
}