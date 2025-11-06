import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Note: CORS is disabled as nginx handles it
  // All requests will come through nginx proxy

  await app.listen(3001, '0.0.0.0');
  console.log(`Reserve API is running on: ${await app.getUrl()}`);
}
bootstrap();
