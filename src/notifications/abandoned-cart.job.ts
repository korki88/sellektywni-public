import { randomUUID } from 'crypto';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { ReservationStatus } from '@prisma/client';
import { MailService } from '../mail/mail.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AbandonedCartJob {
  private readonly log = new Logger(AbandonedCartJob.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly mail: MailService,
    private readonly config: ConfigService,
  ) {}

  @Cron(CronExpression.EVERY_30_MINUTES)
  async run(): Promise<void> {
    if (!this.mail.isEnabled()) {
      return;
    }
    const hours = parseInt(
      this.config.get<string>('ABANDONED_CART_MIN_HOURS')?.trim() || '48',
      10,
    );
    const cutoff = new Date(Date.now() - hours * 3600 * 1000);
    const rows = await this.prisma.productReservation.groupBy({
      by: ['ownerKey'],
      where: {
        status: ReservationStatus.IN_CART,
        updatedAt: { lt: cutoff },
      },
    });
    for (const { ownerKey } of rows) {
      if (!ownerKey.startsWith('user:')) continue;
      const userId = ownerKey.slice('user:'.length).trim();
      if (!userId) continue;
      const lastDay = new Date(Date.now() - 24 * 3600 * 1000);
      const recent = await this.prisma.abandonedCartReminder.findFirst({
        where: { userId, sentAt: { gte: lastDay } },
      });
      if (recent) continue;
      const profile = await this.prisma.profile.findUnique({
        where: { userId },
      });
      const email = profile?.email?.trim();
      if (!email) continue;
      const shopUrl =
        this.config.get<string>('SHOP_PUBLIC_URL')?.trim() ||
        'https://localhost:3000';
      const ok = await this.mail.sendMail({
        to: email,
        subject: 'Masz produkty w koszyku — SELLEKTYWNI',
        text: `Cześć,\n\nTwoje rezerwacje w koszyku czekają. Zakończ zamówienie: ${shopUrl}/app/\n\nPozdrawiamy,\nZespół SELLEKTYWNI`,
        html: `<p>Cześć,</p><p>Twoje produkty w koszyku czekają. <a href="${shopUrl}/app/">Przejdź do sklepu</a></p>`,
      });
      if (ok) {
        await this.prisma.abandonedCartReminder.create({
          data: {
            userId,
            id: randomUUID(),
          },
        });
        this.log.log(`Abandoned cart reminder wysłany do ${email}`);
      }
    }
  }
}
