import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { afterEach, beforeEach, describe, it } from '@jest/globals';
import request from 'supertest';
import { AppModule } from './../src/app.module';
import { PrismaService } from './../src/prisma/prisma.service';

describe('OrderController (e2e)', () => {
  let app: INestApplication;

  beforeEach(async (): Promise<void> => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue({
        onModuleInit: async () => {},
        onModuleDestroy: async () => {},
        $connect: async () => {},
        $disconnect: async () => {},
      })
      .compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();
  });

  it('POST /order bez identyfikatora produktu -> 400', async (): Promise<void> => {
    const server = app.getHttpServer() as Parameters<typeof request>[0];
    await request(server).post('/order').send({}).expect(400);
  });

  afterEach(async (): Promise<void> => {
    await app.close();
  });
});
