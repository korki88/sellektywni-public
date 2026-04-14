import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import type { Transporter } from 'nodemailer';

@Injectable()
export class MailService {
  private readonly log = new Logger(MailService.name);
  private transporter: Transporter | null = null;

  constructor(private readonly config: ConfigService) {
    const host = this.config.get<string>('MAIL_SMTP_HOST')?.trim();
    const port = parseInt(
      this.config.get<string>('MAIL_SMTP_PORT')?.trim() || '0',
      10,
    );
    if (host && port > 0) {
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth:
          this.config.get<string>('MAIL_SMTP_USER') &&
          this.config.get<string>('MAIL_SMTP_PASS')
            ? {
                user: this.config.get<string>('MAIL_SMTP_USER'),
                pass: this.config.get<string>('MAIL_SMTP_PASS'),
              }
            : undefined,
      });
    }
  }

  isEnabled(): boolean {
    return this.transporter != null;
  }

  async sendMail(opts: {
    to: string;
    subject: string;
    text: string;
    html?: string;
  }): Promise<boolean> {
    if (!this.transporter) {
      this.log.debug('MAIL_SMTP_* nie ustawione — pomijam wysyłkę');
      return false;
    }
    const from =
      this.config.get<string>('MAIL_FROM')?.trim() || 'shop@localhost';
    try {
      await this.transporter.sendMail({
        from,
        to: opts.to,
        subject: opts.subject,
        text: opts.text,
        html: opts.html,
      });
      return true;
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      this.log.warn(`SMTP error: ${message}`);
      return false;
    }
  }
}
