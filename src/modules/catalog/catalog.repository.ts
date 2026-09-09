import { Injectable } from '@nestjs/common';
import { PrismaService } from '@shared/database/prisma.service';
import { CreateItemDto, UpdateItemDto, CreateCategoryDto, CatalogQueryDto } from './catalog.schemas';

@Injectable()
export class CatalogRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findItems(storeId: string, query: CatalogQueryDto) {
    const skip = (query.page - 1) * query.limit;
    const where = {
      storeId,
      ...(query.categoryId ? { categoryId: query.categoryId } : {}),
      ...(query.available !== undefined
        ? { isAvailable: query.available === 'true' }
        : {}),
      ...(query.search
        ? { name: { contains: query.search, mode: 'insensitive' as const } }
        : {}),
    };

    const [data, total] = await this.prisma.$transaction([
      this.prisma.item.findMany({
        where,
        include: { category: true },
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
        skip,
        take: query.limit,
      }),
      this.prisma.item.count({ where }),
    ]);

    return { data, total, page: query.page, limit: query.limit };
  }

  findItemById(id: string) {
    return this.prisma.item.findUnique({
      where: { id },
      include: { category: true, store: { select: { id: true, name: true } } },
    });
  }

  findItemsByIds(ids: string[]) {
    return this.prisma.item.findMany({
      where: { id: { in: ids }, isAvailable: true },
    });
  }

  findCategories(storeId: string) {
    return this.prisma.category.findMany({
      where: { storeId },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      include: { _count: { select: { items: true } } },
    });
  }

  createItem(storeId: string, data: CreateItemDto) {
    return this.prisma.item.create({
      data: { ...data, storeId },
      include: { category: true },
    });
  }

  updateItem(id: string, data: UpdateItemDto) {
    return this.prisma.item.update({
      where: { id },
      data,
      include: { category: true },
    });
  }

  deleteItem(id: string) {
    return this.prisma.item.delete({ where: { id } });
  }

  createCategory(storeId: string, data: CreateCategoryDto) {
    return this.prisma.category.create({ data: { ...data, storeId } });
  }
}
