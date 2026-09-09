import { Injectable } from '@nestjs/common';
import { PrismaService } from '@shared/database/prisma.service';
import { CreateStoreDto, UpdateStoreDto } from './stores.schemas';

@Injectable()
export class StoresRepository {
  constructor(private readonly prisma: PrismaService) {}

  findAll() {
    return this.prisma.store.findMany({
      where: { isActive: true },
      include: { area: true, _count: { select: { items: true } } },
      orderBy: { name: 'asc' },
    });
  }

  findById(id: string) {
    return this.prisma.store.findUnique({
      where: { id },
      include: { area: true },
    });
  }

  findAllAreas() {
    return this.prisma.area.findMany({ orderBy: { name: 'asc' } });
  }

  create(data: CreateStoreDto) {
    return this.prisma.store.create({ data, include: { area: true } });
  }

  update(id: string, data: UpdateStoreDto) {
    return this.prisma.store.update({ where: { id }, data, include: { area: true } });
  }
}
