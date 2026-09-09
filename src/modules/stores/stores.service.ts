import { Injectable, NotFoundException } from '@nestjs/common';
import { StoresRepository } from './stores.repository';
import { CreateStoreDto, UpdateStoreDto } from './stores.schemas';

@Injectable()
export class StoresService {
  constructor(private readonly repo: StoresRepository) {}

  getAll() { return this.repo.findAll(); }

  async getById(id: string) {
    const store = await this.repo.findById(id);
    if (!store) throw new NotFoundException('Store not found');
    return store;
  }

  getAreas() { return this.repo.findAllAreas(); }

  create(dto: CreateStoreDto) { return this.repo.create(dto); }

  async update(id: string, dto: UpdateStoreDto) {
    await this.getById(id);
    return this.repo.update(id, dto);
  }
}
