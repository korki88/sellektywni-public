import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import express from 'express';
import { join } from 'path';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.enableCors({ origin: true, credentials: true });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const wwwAppPath = join(__dirname, '..', 'www', 'app');
  const expressApp = app.getHttpAdapter().getInstance();

  expressApp.get('/', (_req: express.Request, res: express.Response) => {
    res.redirect(302, '/app/');
  });

  app.useStaticAssets(wwwAppPath, { prefix: '/app/' });

  expressApp.use(
    '/app',
    (
      req: express.Request,
      res: express.Response,
      next: express.NextFunction,
    ) => {
      if (req.method !== 'GET' && req.method !== 'HEAD') {
        next();
        return;
      }
      const leaf = req.path.split('/').filter(Boolean).pop() ?? '';
      if (leaf.includes('.')) {
        next();
        return;
      }
      res.sendFile(join(wwwAppPath, 'index.html'), (err) => {
        if (err) next(err);
      });
    },
  );

  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
