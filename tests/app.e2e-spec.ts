import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalExceptionFilter } from '../src/shared/filters/http-exception.filter';

describe('Esook API (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
    app.useGlobalFilters(new GlobalExceptionFilter());
    await app.init();
  });

  afterAll(async () => { await app.close(); });

  it('/health returns status field', async () => {
    const res = await request(app.getHttpServer()).get('/health');
    expect(res.status).toBeLessThan(500);
    expect(res.body).toHaveProperty('status');
    expect(res.body).toHaveProperty('services');
  });

  it('POST /auth/otp/send rejects invalid phone', async () => {
    const res = await request(app.getHttpServer())
      .post('/auth/otp/send')
      .send({ phone: 'not-a-phone' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_INPUT');
  });

  it('POST /auth/staff/login returns 401 for unknown email', async () => {
    const res = await request(app.getHttpServer())
      .post('/auth/staff/login')
      .send({ email: 'nobody@esook.store', password: 'wrongpassword123' });
    expect(res.status).toBe(401);
  });

  it('GET /stores returns array', async () => {
    const res = await request(app.getHttpServer()).get('/stores');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('GET /stores/areas returns array', async () => {
    const res = await request(app.getHttpServer()).get('/stores/areas');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('GET /cart requires auth', async () => {
    const res = await request(app.getHttpServer()).get('/cart');
    expect(res.status).toBe(401);
  });

  it('POST /orders requires auth', async () => {
    const res = await request(app.getHttpServer())
      .post('/orders')
      .send({ storeId: 'x', fulfillment: 'PICKUP', items: [] });
    expect(res.status).toBe(401);
  });
});
