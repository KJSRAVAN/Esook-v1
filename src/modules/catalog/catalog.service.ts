import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { CatalogRepository } from './catalog.repository';
import {
  CreateItemDto, UpdateItemDto, CreateCategoryDto, CatalogQueryDto,
} from './catalog.schemas';

interface AuthUser { id: string; role: string; storeId: string | null; }

@Injectable()
export class CatalogService {
  constructor(private readonly repo: CatalogRepository) {}

  getItems(storeId: string, query: CatalogQueryDto) {
    return this.repo.findItems(storeId, query);
  }

  async getItemById(id: string) {
    const item = await this.repo.findItemById(id);
    if (!item) throw new NotFoundException('Item not found');
    return item;
  }

  getCategories(storeId: string) {
    return this.repo.findCategories(storeId);
  }

  async createItem(storeId: string, dto: CreateItemDto, actor: AuthUser) {
    this.assertStoreAccess(actor, storeId);
    return this.repo.createItem(storeId, dto);
  }

  async updateItem(id: string, dto: UpdateItemDto, actor: AuthUser) {
    const item = await this.repo.findItemById(id);
    if (!item) throw new NotFoundException('Item not found');
    this.assertStoreAccess(actor, item.storeId);
    return this.repo.updateItem(id, dto);
  }

  async deleteItem(id: string, actor: AuthUser) {
    const item = await this.repo.findItemById(id);
    if (!item) throw new NotFoundException('Item not found');
    this.assertStoreAccess(actor, item.storeId);
    return this.repo.deleteItem(id);
  }

  async createCategory(storeId: string, dto: CreateCategoryDto, actor: AuthUser) {
    this.assertStoreAccess(actor, storeId);
    return this.repo.createCategory(storeId, dto);
  }

  private assertStoreAccess(actor: AuthUser, storeId: string): void {
    if (actor.role === 'SUPER_ADMIN') return;
    if (actor.storeId !== storeId)
      throw new ForbiddenException('Access to this store is not allowed');
  }
}
