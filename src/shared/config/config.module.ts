import { Global, Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { envSchema } from './config.schema';

@Global()
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: (config) => {
        const result = envSchema.safeParse(config);
        if (!result.success) {
          console.error('❌ Invalid environment variables:', result.error.flatten());
          throw new Error('Invalid environment variables');
        }
        return result.data;
      },
    }),
  ],
})
export class AppConfigModule {}
