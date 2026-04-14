import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, ProductStatus, ReservationStatus } from '@prisma/client';
import * as XLSX from 'xlsx';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class StaffProductsService {
  constructor(private readonly prisma: PrismaService) {}

  private normalizeHeader(raw: string): string {
    return raw
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '');
  }

  private toCellText(value: unknown): string | undefined {
    if (typeof value === 'string') return value;
    if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value);
    }
    return undefined;
  }

  private findValue(
    row: Record<string, unknown>,
    aliases: string[],
  ): string | undefined {
    const normalizedAliases = aliases.map((a) => this.normalizeHeader(a));
    for (const [key, value] of Object.entries(row)) {
      const nk = this.normalizeHeader(key);
      if (!normalizedAliases.includes(nk)) continue;
      const asText = this.toCellText(value)?.trim() ?? '';
      if (asText.length > 0) return asText;
    }
    return undefined;
  }

  private parseDecimal(
    raw: string | undefined,
    fieldName: string,
  ): Prisma.Decimal | null {
    if (!raw) return null;
    const normalized = raw.replace(',', '.').trim();
    const num = Number(normalized);
    if (!Number.isFinite(num)) {
      throw new BadRequestException(
        `Nieprawidłowa liczba w polu ${fieldName}: "${raw}"`,
      );
    }
    return new Prisma.Decimal(normalized);
  }

  private parseIntNumber(
    raw: string | undefined,
    fieldName: string,
  ): number | null {
    if (!raw) return null;
    const num = Number(raw.trim());
    if (!Number.isFinite(num)) {
      throw new BadRequestException(
        `Nieprawidłowa liczba całkowita w polu ${fieldName}: "${raw}"`,
      );
    }
    return Math.trunc(num);
  }

  private userIdFromOwnerKey(ownerKey: string): string | null {
    if (!ownerKey.startsWith('user:')) {
      return null;
    }
    const userId = ownerKey.slice('user:'.length).trim();
    return userId.length > 0 ? userId : null;
  }

  async listPendingApproval() {
    const products = await this.prisma.product.findMany({
      where: {
        reservations: {
          some: { status: ReservationStatus.PENDING },
        },
      },
      orderBy: { createdAt: 'asc' },
      include: {
        reservations: {
          where: { status: ReservationStatus.PENDING },
          select: { quantity: true },
        },
      },
    });
    return products.map(({ reservations, ...p }) => {
      const finalQuantity = reservations.reduce((s, r) => s + r.quantity, 0);
      return {
        ...p,
        // Backward compatibility: stare rekordy PENDING_APPROVAL bez rezerwacji.
        pendingQuantity: finalQuantity > 0 ? finalQuantity : 1,
      };
    });
  }

  /** Akceptacja rezerwacji — produkt sprzedany. */
  async acceptReservation(productId: string) {
    const p = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!p) throw new NotFoundException('Produkt nie istnieje');
    const pendingRows = await this.prisma.productReservation.findMany({
      where: { productId, status: ReservationStatus.PENDING },
      select: { quantity: true },
    });
    const pendingQty = pendingRows.reduce((sum, r) => sum + r.quantity, 0);
    if (pendingQty <= 0) {
      throw new NotFoundException('Produkt nie oczekuje na akceptację');
    }
    const newStock = Math.max(0, p.stockQty - pendingQty);
    const inCartRows = await this.prisma.productReservation.findMany({
      where: { productId, status: ReservationStatus.IN_CART },
      select: { quantity: true },
    });
    const inCartQty = inCartRows.reduce((sum, r) => sum + r.quantity, 0);
    const nextStatus =
      newStock <= 0
        ? ProductStatus.SOLD
        : newStock - inCartQty <= 0
          ? ProductStatus.RESERVED
          : ProductStatus.AVAILABLE;
    const [updated] = await this.prisma.$transaction([
      this.prisma.product.update({
        where: { id: productId },
        data: {
          stockQty: newStock,
          status: nextStatus,
        },
      }),
      this.prisma.productReservation.updateMany({
        where: { productId, status: ReservationStatus.PENDING },
        data: { status: ReservationStatus.ACCEPTED },
      }),
    ]);
    return {
      ...updated,
      pendingQuantity: 0,
    };
  }

  /** Odrzucenie — produkt wraca do sprzedaży. */
  async rejectReservation(productId: string) {
    const p = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!p) throw new NotFoundException('Produkt nie istnieje');
    const pendingRows = await this.prisma.productReservation.findMany({
      where: { productId, status: ReservationStatus.PENDING },
      select: { quantity: true, ownerKey: true },
    });
    const pendingQty = pendingRows.reduce((sum, r) => sum + r.quantity, 0);
    if (pendingQty <= 0) {
      throw new NotFoundException('Produkt nie oczekuje na akceptację');
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      const changedAt = new Date();
      await tx.productReservation.updateMany({
        where: { productId, status: ReservationStatus.PENDING },
        data: { status: ReservationStatus.REJECTED, updatedAt: changedAt },
      });
      for (const row of pendingRows) {
        const userId = this.userIdFromOwnerKey(row.ownerKey);
        if (!userId) continue;
        await tx.availabilityWatch.upsert({
          where: {
            userId_productId: { userId, productId },
          },
          create: { userId, productId },
          update: {},
        });
      }
      return tx.product.update({
        where: { id: productId },
        data: { status: ProductStatus.RESERVED },
      });
    });
    return {
      ...updated,
      pendingQuantity: 0,
    };
  }

  async updateMerchandising(
    productId: string,
    data: { isFeatured?: boolean; subtitle?: string | null },
  ) {
    const p = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!p) throw new NotFoundException('Produkt nie istnieje');
    return this.prisma.product.update({
      where: { id: productId },
      data: {
        ...(data.isFeatured !== undefined
          ? { isFeatured: data.isFeatured }
          : {}),
        ...(data.subtitle !== undefined ? { subtitle: data.subtitle } : {}),
      },
    });
  }

  async importCostingSheet(fileBuffer: Buffer, fileName: string) {
    const wb = XLSX.read(fileBuffer, { type: 'buffer' });
    const firstSheetName = wb.SheetNames[0];
    if (!firstSheetName) {
      throw new BadRequestException('Plik nie zawiera arkusza.');
    }
    const sheet = wb.Sheets[firstSheetName];
    const rows = XLSX.utils.sheet_to_json<Record<string, unknown>>(sheet, {
      defval: '',
      raw: false,
    });
    if (rows.length === 0) {
      throw new BadRequestException('Plik nie zawiera żadnych danych.');
    }

    let updatedProducts = 0;
    let upsertedSuppliers = 0;
    const warnings: string[] = [];

    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const rowNo = i + 2;
      const productId = this.findValue(row, ['productId', 'product_id', 'id']);
      const idDotykacka = this.findValue(row, [
        'idDotykacka',
        'id_dotykacka',
        'dotykacka',
      ]);
      if (!productId && !idDotykacka) {
        warnings.push(
          `Wiersz ${rowNo}: brak productId lub idDotykacka — pominięto.`,
        );
        continue;
      }

      const purchasePriceNet = this.parseDecimal(
        this.findValue(row, [
          'purchasePriceNet',
          'purchase_price_net',
          'costNet',
        ]),
        'purchasePriceNet',
      );
      const vatRate = this.parseDecimal(
        this.findValue(row, ['vatRate', 'vat_rate', 'vat']),
        'vatRate',
      );
      const marginTarget = this.parseDecimal(
        this.findValue(row, ['marginTarget', 'margin_target', 'margin']),
        'marginTarget',
      );
      const supplierName = this.findValue(row, [
        'supplier',
        'supplierName',
        'supplier_name',
      ]);
      const paymentTermsDays = this.parseIntNumber(
        this.findValue(row, ['paymentTermsDays', 'payment_terms_days']),
        'paymentTermsDays',
      );

      let supplierId: string | undefined;
      if (supplierName) {
        const supplier = await this.prisma.supplier.upsert({
          where: { name: supplierName },
          create: {
            name: supplierName,
            paymentTermsDays: paymentTermsDays ?? undefined,
          },
          update: {
            ...(paymentTermsDays !== null ? { paymentTermsDays } : {}),
          },
        });
        supplierId = supplier.id;
        upsertedSuppliers += 1;
      }

      const where = productId
        ? { id: productId }
        : { idDotykacka: idDotykacka! };
      const existing = await this.prisma.product.findFirst({
        where: productId ? { id: productId } : { idDotykacka: idDotykacka! },
        select: { id: true },
      });
      if (!existing) {
        warnings.push(
          `Wiersz ${rowNo}: produkt nie istnieje (${productId ?? idDotykacka}) — pominięto.`,
        );
        continue;
      }

      await this.prisma.product.update({
        where,
        data: {
          ...(purchasePriceNet !== null ? { purchasePriceNet } : {}),
          ...(vatRate !== null ? { vatRate } : {}),
          ...(marginTarget !== null ? { marginTarget } : {}),
          ...(supplierId ? { supplierId } : {}),
        },
      });
      updatedProducts += 1;
    }

    return {
      fileName,
      rowsTotal: rows.length,
      updatedProducts,
      upsertedSuppliers,
      warnings,
    };
  }
}
