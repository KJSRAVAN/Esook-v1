import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from '@shared/filters/http-exception.filter';
import { TimeoutInterceptor } from '@shared/interceptors/timeout.interceptor';

async function bootstrap(): Promise<void> {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
  });

  // Security headers
  app.use(helmet());

  // CORS — explicit origins required in production
  const rawOrigins = process.env.CORS_ORIGINS;
  if (!rawOrigins && process.env.NODE_ENV === 'production') {
    throw new Error('CORS_ORIGINS must be set in production. Refusing to start with allow-all CORS.');
  }
  const corsOrigins = rawOrigins?.split(',').map((o) => o.trim()) ?? [];
  app.enableCors({
    origin: corsOrigins.length ? corsOrigins : true, // true = allow-all in dev only
    credentials: true,
  });

  // Global pipes / filters / interceptors
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new GlobalExceptionFilter());
  app.useGlobalInterceptors(new TimeoutInterceptor());

  // OpenAPI / Swagger
  if (process.env.NODE_ENV !== 'production') {
    const docConfig = new DocumentBuilder()
      .setTitle('Esook API')
      .setDescription('Esook e-store backend API')
      .setVersion('2.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, docConfig);
    SwaggerModule.setup('api/docs', app, document);
    logger.log('Swagger UI available at /api/docs');
  }

  const port = process.env.PORT ?? 4000;

  // Enable graceful shutdown — NestJS will call onModuleDestroy() on SIGTERM/SIGINT
  // so PrismaService and RedisService can close their connections cleanly.
  app.enableShutdownHooks();

  await app.listen(port);
  logger.log(`Application running on port ${port}`);
}

bootstrap();
