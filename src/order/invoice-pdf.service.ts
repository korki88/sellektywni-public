import { Injectable, NotFoundException } from '@nestjs/common';
import PDFDocument from 'pdfkit';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class InvoicePdfService {
  constructor(private readonly prisma: PrismaService) {}

  async buildOrderInvoicePdf(userId: string, orderId: string): Promise<Buffer> {
    const order = await this.prisma.customerOrder.findFirst({
      where: { id: orderId, userId },
      include: { items: true },
    });
    if (!order) {
      throw new NotFoundException('Zamówienie nie istnieje');
    }
    const chunks: Buffer[] = [];
    const doc = new PDFDocument({ margin: 50, size: 'A4' });
    doc.on('data', (c: Buffer) => chunks.push(c));
    const done = new Promise<Buffer>((resolve, reject) => {
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);
    });

    doc
      .fontSize(16)
      .text('Dokument sprzedaży / zamówienie', { align: 'center' });
    doc.moveDown(0.5);
    doc.fontSize(10).text(`Numer: ${order.id}`);
    doc.text(`Data: ${order.createdAt.toISOString()}`);
    doc.moveDown();
    doc.fontSize(11).text('Pozycje:', { underline: true });
    doc.moveDown(0.3);
    for (const it of order.items) {
      doc
        .fontSize(10)
        .text(
          `${it.name} — ${it.quantity} szt. × ${String(it.price)} PLN = ${String(it.lineTotal)} PLN`,
        );
    }
    doc.moveDown();
    doc.text(`Wartość pozycji: ${String(order.subtotalAmount)} PLN`);
    if (Number(order.discountAmount) > 0) {
      doc.text(`Rabat (promo): -${String(order.discountAmount)} PLN`);
    }
    if (Number(order.referralDiscountAmount) > 0) {
      doc.text(
        `Rabat (polecenie): -${String(order.referralDiscountAmount)} PLN`,
      );
    }
    if (Number(order.giftCardDiscountAmount) > 0) {
      doc.text(
        `Karta podarunkowa: -${String(order.giftCardDiscountAmount)} PLN`,
      );
    }
    doc.fontSize(12).text(`Do zapłaty: ${String(order.totalAmount)} PLN`, {
      continued: false,
    });
    doc.moveDown(2);
    doc
      .fontSize(8)
      .fillColor('#666666')
      .text(
        'Dokument informacyjny wygenerowany elektronicznie w systemie sklepu.',
        { align: 'center' },
      );
    doc.end();
    return done;
  }
}
