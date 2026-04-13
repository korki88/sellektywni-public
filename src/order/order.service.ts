import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import {
  AddressBookEntryType,
  PaymentMethod,
  PaymentStatus,
  Prisma,
  ProductStatus,
  ReservationStatus,
  ShippingMethod,
} from '@prisma/client';
import { MarketService } from '../core/market/market.service';
import { DotykackaService } from '../dotykacka/dotykacka.service';
import { AdminNotificationService } from '../notification/admin-notification.service';
import { PaymentsService } from '../payments/payments.service';
import { PromoService } from '../promo/promo.service';
import { ProductService } from '../product/product.service';
import { PrismaService } from '../prisma/prisma.service';
import { ShippingService } from '../shipping/shipping.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { FinalizeOrderDto } from './dto/finalize-order.dto';
import { SubmitCartDto } from './dto/submit-cart.dto';
import { UpdateCheckoutPreferencesDto } from './dto/update-checkout-preferences.dto';
import { UpsertAddressBookEntryDto } from './dto/upsert-address-book-entry.dto';

@Injectable()
export class OrderService implements OnModuleInit, OnModuleDestroy {
  private static readonly REJECTED_AUTO_REMOVE_MINUTES = 15;
  private static readonly REJECTED_CLEANUP_INTERVAL_MS = 60_000;
  private readonly logger = new Logger(OrderService.name);
  private cleanupTimer: NodeJS.Timeout | null = null;
  private cleanupRunning = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly productService: ProductService,
    private readonly promoService: PromoService,
    private readonly dotykacka: DotykackaService,
    private readonly adminNotification: AdminNotificationService,
    private readonly payments: PaymentsService,
    private readonly shipping: ShippingService,
    private readonly market: MarketService,
  ) {}

  private normalizeOwnerKey(ownerKey?: string): string {
    const v = ownerKey?.trim();
    return v && v.length > 0 ? v : 'legacy:unknown';
  }

  private ownerKeyFromUser(userId: string): string {
    return `user:${userId}`;
  }

  private userIdFromOwnerKey(ownerKey: string): string | null {
    if (!ownerKey.startsWith('user:')) {
      return null;
    }
    const userId = ownerKey.slice('user:'.length).trim();
    return userId.length > 0 ? userId : null;
  }

  private async ensureAvailabilityWatchTx(
    tx: Prisma.TransactionClient,
    ownerKey: string,
    productId: string,
  ) {
    const userId = this.userIdFromOwnerKey(ownerKey);
    if (!userId) return;
    await tx.availabilityWatch.upsert({
      where: {
        userId_productId: { userId, productId },
      },
      create: { userId, productId },
      update: {},
    });
  }

  private async cleanupExpiredRejectedReservations(userId: string) {
    const ownerKey = this.ownerKeyFromUser(userId);
    const cutoff = new Date(
      Date.now() - OrderService.REJECTED_AUTO_REMOVE_MINUTES * 60 * 1000,
    );
    const rows = await this.prisma.productReservation.findMany({
      where: {
        ownerKey,
        status: {
          in: [ReservationStatus.REJECTED, ReservationStatus.AUTO_REJECTED],
        },
        updatedAt: { lte: cutoff },
      },
      select: { id: true },
    });
    if (rows.length === 0) return 0;
    await this.prisma.productReservation.deleteMany({
      where: { id: { in: rows.map((r) => r.id) } },
    });
    return rows.length;
  }

  private async cleanupExpiredRejectedReservationsGlobal() {
    if (this.cleanupRunning) return;
    this.cleanupRunning = true;
    try {
      const cutoff = new Date(
        Date.now() - OrderService.REJECTED_AUTO_REMOVE_MINUTES * 60 * 1000,
      );
      const rows = await this.prisma.productReservation.findMany({
        where: {
          status: {
            in: [ReservationStatus.REJECTED, ReservationStatus.AUTO_REJECTED],
          },
          updatedAt: { lte: cutoff },
        },
        select: { id: true },
      });
      if (rows.length === 0) return;
      await this.prisma.productReservation.deleteMany({
        where: { id: { in: rows.map((r) => r.id) } },
      });
      this.logger.log(
        `Auto-usunięto ${rows.length} odrzuconych rezerwacji starszych niż 15 minut`,
      );
    } finally {
      this.cleanupRunning = false;
    }
  }

  onModuleInit() {
    this.cleanupTimer = setInterval(() => {
      void this.cleanupExpiredRejectedReservationsGlobal();
    }, OrderService.REJECTED_CLEANUP_INTERVAL_MS);
    void this.cleanupExpiredRejectedReservationsGlobal();
  }

  onModuleDestroy() {
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = null;
    }
  }

  private normalizeAddressPayload(
    shippingMethod: ShippingMethod,
    input: {
      label?: string;
      recipientName?: string;
      phone?: string;
      email?: string;
      country?: string;
      postalCode?: string;
      city?: string;
      street?: string;
      buildingNumber?: string;
      apartmentNumber?: string;
      parcelLockerId?: string;
      parcelLockerLabel?: string;
    },
  ) {
    const out = {
      label: input.label?.trim() || null,
      recipientName: input.recipientName?.trim() || null,
      phone: input.phone?.trim() || null,
      email: input.email?.trim() || null,
      country: (
        input.country?.trim() || this.market.primaryCountryCode()
      ).toUpperCase(),
      postalCode: input.postalCode?.trim() || null,
      city: input.city?.trim() || null,
      street: input.street?.trim() || null,
      buildingNumber: input.buildingNumber?.trim() || null,
      apartmentNumber: input.apartmentNumber?.trim() || null,
      parcelLockerId: input.parcelLockerId?.trim() || null,
      parcelLockerLabel: input.parcelLockerLabel?.trim() || null,
    };
    if (!this.market.isCountrySupported(out.country)) {
      throw new BadRequestException(
        this.market.unsupportedShippingCountryMessage(out.country),
      );
    }
    if (!out.phone) {
      throw new BadRequestException('Podaj numer telefonu do kontaktu.');
    }
    if (shippingMethod === ShippingMethod.PARCEL_LOCKER_INPOST) {
      if (!out.parcelLockerId) {
        throw new BadRequestException('Podaj identyfikator paczkomatu InPost.');
      }
      return out;
    }
    if (shippingMethod === ShippingMethod.COURIER) {
      if (!out.postalCode || !out.city || !out.street || !out.buildingNumber) {
        throw new BadRequestException(
          'Dla kuriera podaj pełny adres: kod pocztowy, miasto, ulicę i numer budynku.',
        );
      }
    }
    if (shippingMethod === ShippingMethod.STORE_PICKUP && !out.recipientName) {
      throw new BadRequestException('Podaj imię i nazwisko odbiorcy.');
    }
    return out;
  }

  private async lastOrderDefaults(userId: string) {
    const lastOrder = await this.prisma.customerOrder.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
    if (!lastOrder) return null;
    const snapshot = (lastOrder.shippingSnapshot ?? {}) as Record<
      string,
      unknown
    >;
    return {
      paymentMethod: lastOrder.paymentMethod,
      shippingMethod: lastOrder.shippingMethod,
      shippingTarget: snapshot,
    };
  }

  private async resolveCheckoutDefaults(userId: string) {
    const [preference, addressBook, lastOrder] = await Promise.all([
      this.prisma.checkoutPreference.findUnique({ where: { userId } }),
      this.prisma.addressBookEntry.findMany({
        where: { userId },
        orderBy: [{ isDefault: 'desc' }, { updatedAt: 'desc' }],
      }),
      this.lastOrderDefaults(userId),
    ]);
    const preferredAddress =
      (preference?.preferredAddressId
        ? addressBook.find((a) => a.id === preference.preferredAddressId)
        : null) ??
      addressBook.find((a) => a.isDefault) ??
      null;
    return {
      paymentMethod:
        preference?.preferredPaymentMethod ??
        lastOrder?.paymentMethod ??
        PaymentMethod.BLIK,
      shippingMethod:
        preference?.preferredShippingMethod ??
        lastOrder?.shippingMethod ??
        ShippingMethod.COURIER,
      preferredAddressId: preferredAddress?.id ?? null,
      source:
        preference?.preferredPaymentMethod ||
        preference?.preferredShippingMethod
          ? 'settings'
          : lastOrder
            ? 'last-order'
            : 'defaults',
    };
  }

  private async recalcProductStatusTx(
    tx: Prisma.TransactionClient,
    productId: string,
  ) {
    const p = await tx.product.findUnique({
      where: { id: productId },
      include: {
        reservations: {
          where: {
            status: {
              in: [ReservationStatus.IN_CART, ReservationStatus.PENDING],
            },
          },
          select: { quantity: true },
        },
      },
    });
    if (!p) throw new NotFoundException('Produkt nie istnieje');
    const reserved = p.reservations.reduce((sum, r) => sum + r.quantity, 0);
    const available = p.stockQty - reserved;
    const status =
      p.stockQty <= 0
        ? ProductStatus.SOLD
        : available <= 0
          ? ProductStatus.RESERVED
          : ProductStatus.AVAILABLE;
    return tx.product.update({
      where: { id: productId },
      data: { status },
    });
  }

  private async trimReservationsToStock(
    tx: Prisma.TransactionClient,
    productId: string,
    stockQty: number,
  ): Promise<number> {
    const pendingRows = await tx.productReservation.findMany({
      where: { productId, status: ReservationStatus.PENDING },
      orderBy: { createdAt: 'desc' },
    });
    const pendingTotal = pendingRows.reduce((sum, r) => sum + r.quantity, 0);
    if (pendingTotal <= stockQty) return 0;
    let excess = pendingTotal - stockQty;
    let autoRejected = 0;
    for (const row of pendingRows) {
      if (excess <= 0) break;
      const rejectedNow = Math.min(row.quantity, excess);
      if (rejectedNow <= 0) continue;
      excess -= rejectedNow;
      autoRejected += rejectedNow;
      if (row.quantity === rejectedNow) {
        await tx.productReservation.update({
          where: { id: row.id },
          data: {
            status: ReservationStatus.AUTO_REJECTED,
            updatedAt: new Date(),
          },
        });
        await this.ensureAvailabilityWatchTx(tx, row.ownerKey, row.productId);
      } else {
        await tx.productReservation.update({
          where: { id: row.id },
          data: { quantity: { decrement: rejectedNow } },
        });
        await tx.productReservation.upsert({
          where: {
            ownerKey_productId_status: {
              ownerKey: row.ownerKey,
              productId: row.productId,
              status: ReservationStatus.AUTO_REJECTED,
            },
          },
          create: {
            ownerKey: row.ownerKey,
            productId: row.productId,
            quantity: rejectedNow,
            status: ReservationStatus.AUTO_REJECTED,
          },
          update: {
            quantity: { increment: rejectedNow },
            updatedAt: new Date(),
          },
        });
        await this.ensureAvailabilityWatchTx(tx, row.ownerKey, row.productId);
      }
    }
    return autoRejected;
  }

  private async syncProductStock(productId: string) {
    const p = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!p) throw new NotFoundException('Produkt nie istnieje');
    const stockQty = await this.dotykacka.resolveStockQty(p);
    if (stockQty !== p.stockQty) {
      return this.prisma.$transaction(async (tx) => {
        await tx.product.update({
          where: { id: p.id },
          data: { stockQty },
        });
        return this.recalcProductStatusTx(tx, p.id);
      });
    }
    return p;
  }

  private async recalcProductStatus(productId: string) {
    return this.prisma.$transaction(async (tx) => {
      return this.recalcProductStatusTx(tx, productId);
    });
  }

  async reserveInCart(dto: CreateOrderDto, userId: string) {
    if (!dto.productId && !dto.idDotykacka) {
      throw new BadRequestException('Podaj productId lub idDotykacka');
    }
    const qty = dto.quantity ?? 1;
    if (qty <= 0) throw new BadRequestException('quantity musi być >= 1');
    const ownerKey = this.ownerKeyFromUser(userId);
    const existing = await this.productService.findByIdOrDotykacka(
      dto.productId,
      dto.idDotykacka,
    );
    if (!existing) throw new NotFoundException('Produkt nie istnieje');
    const synced = await this.syncProductStock(existing.id);
    try {
      const result = await this.prisma.$transaction(async (tx) => {
        const locked = await tx.product.findUnique({
          where: { id: synced.id },
        });
        if (!locked) throw new NotFoundException('Produkt nie istnieje');

        const latestStock = await this.dotykacka.resolveStockQty(locked);
        let effectiveStock = locked.stockQty;
        if (latestStock !== locked.stockQty) {
          effectiveStock = latestStock;
          await tx.product.update({
            where: { id: locked.id },
            data: { stockQty: latestStock },
          });
        }

        const autoRejectedByStoreSale = await this.trimReservationsToStock(
          tx,
          locked.id,
          effectiveStock,
        );

        const reservedRows = await tx.productReservation.findMany({
          where: {
            productId: locked.id,
            status: {
              in: [ReservationStatus.IN_CART, ReservationStatus.PENDING],
            },
          },
          select: { quantity: true },
        });
        const reservedQty = reservedRows.reduce(
          (sum, r) => sum + r.quantity,
          0,
        );
        const availableQty = effectiveStock - reservedQty;
        const keepReservedUntilStockSync =
          locked.status === ProductStatus.RESERVED &&
          latestStock === locked.stockQty &&
          availableQty > 0;
        if (keepReservedUntilStockSync) {
          throw new ConflictException('PRODUCT_RESERVED_UNTIL_STOCK_SYNC');
        }
        const syncedStatus =
          effectiveStock <= 0
            ? ProductStatus.SOLD
            : availableQty <= 0
              ? ProductStatus.RESERVED
              : ProductStatus.AVAILABLE;
        if (locked.status !== syncedStatus) {
          await tx.product.update({
            where: { id: locked.id },
            data: { status: syncedStatus },
          });
        }
        if (availableQty < qty) {
          throw new ConflictException('PRODUCT_NOT_AVAILABLE_NOW');
        }

        await tx.productReservation.upsert({
          where: {
            ownerKey_productId_status: {
              ownerKey,
              productId: locked.id,
              status: ReservationStatus.PENDING,
            },
          },
          create: {
            ownerKey,
            productId: locked.id,
            quantity: qty,
            status: ReservationStatus.PENDING,
          },
          update: {
            quantity: { increment: qty },
          },
        });
        await tx.availabilityWatch.deleteMany({
          where: { userId, productId: locked.id },
        });
        const product = await this.recalcProductStatusTx(tx, locked.id);
        return { product, autoRejectedByStoreSale };
      });
      await this.adminNotification.notifyOrderPendingApproval(result.product);
      return {
        message: 'Produkt został dodany do koszyka i przekazany do akceptacji.',
        quantity: qty,
        ownerKey,
        product: result.product,
        autoRejectedByStoreSale: result.autoRejectedByStoreSale,
      };
    } catch (error) {
      if (error instanceof ConflictException) {
        await this.prisma.availabilityWatch.upsert({
          where: {
            userId_productId: {
              userId,
              productId: existing.id,
            },
          },
          create: {
            userId,
            productId: existing.id,
          },
          update: {},
        });
        throw new ConflictException({
          code: 'PRODUCT_ALREADY_RESERVED_OR_SOLD',
          message:
            'Dziękujemy za zainteresowanie. Ten produkt został właśnie zarezerwowany lub sprzedany w sklepie stacjonarnym. Sprzedaż stacjonarna ma pierwszeństwo.',
          suggestion:
            'Włączyliśmy dla Ciebie powiadomienie o ponownej dostępności tego produktu.',
        });
      }
      throw error;
    }
  }

  async releaseFromCart(dto: CreateOrderDto, userId: string) {
    if (!dto.productId && !dto.idDotykacka) {
      throw new BadRequestException('Podaj productId lub idDotykacka');
    }
    const qty = dto.quantity ?? 1;
    if (qty <= 0) throw new BadRequestException('quantity musi być >= 1');
    const ownerKey = this.ownerKeyFromUser(userId);
    const existing = await this.productService.findByIdOrDotykacka(
      dto.productId,
      dto.idDotykacka,
    );
    if (!existing) throw new NotFoundException('Produkt nie istnieje');
    const row =
      (await this.prisma.productReservation.findUnique({
        where: {
          ownerKey_productId_status: {
            ownerKey,
            productId: existing.id,
            status: ReservationStatus.PENDING,
          },
        },
      })) ??
      (await this.prisma.productReservation.findUnique({
        where: {
          ownerKey_productId_status: {
            ownerKey,
            productId: existing.id,
            status: ReservationStatus.IN_CART,
          },
        },
      }));
    if (!row) {
      return { message: 'Brak aktywnej rezerwacji do zwolnienia', ownerKey };
    }
    if (row.quantity <= qty) {
      await this.prisma.productReservation.delete({ where: { id: row.id } });
    } else {
      await this.prisma.productReservation.update({
        where: { id: row.id },
        data: { quantity: { decrement: qty } },
      });
    }
    const product = await this.recalcProductStatus(existing.id);
    return {
      message: 'Zwolniono rezerwację z koszyka',
      quantity: qty,
      product,
      ownerKey,
    };
  }

  async submitCart(_dto: SubmitCartDto, userId: string) {
    const ownerKey = this.ownerKeyFromUser(userId);
    const rows = await this.prisma.productReservation.findMany({
      where: {
        ownerKey,
        status: ReservationStatus.IN_CART,
      },
      include: { product: true },
    });
    if (rows.length === 0) {
      return { submittedLines: 0, submittedItems: 0, autoRejected: 0 };
    }
    let submittedItems = 0;
    let autoRejected = 0;
    for (const row of rows) {
      const synced = await this.syncProductStock(row.productId);
      if (synced.stockQty < row.quantity) {
        await this.prisma.productReservation.update({
          where: { id: row.id },
          data: {
            status: ReservationStatus.AUTO_REJECTED,
            updatedAt: new Date(),
          },
        });
        const userId = this.userIdFromOwnerKey(row.ownerKey);
        if (userId) {
          await this.prisma.availabilityWatch.upsert({
            where: {
              userId_productId: { userId, productId: row.productId },
            },
            create: { userId, productId: row.productId },
            update: {},
          });
        }
        autoRejected += row.quantity;
        await this.recalcProductStatus(row.productId);
        continue;
      }
      await this.prisma.productReservation.update({
        where: { id: row.id },
        data: { status: ReservationStatus.PENDING },
      });
      submittedItems += row.quantity;
      await this.adminNotification.notifyOrderPendingApproval(synced);
      await this.recalcProductStatus(row.productId);
    }
    return {
      submittedLines: rows.length,
      submittedItems,
      autoRejected,
    };
  }

  async placePendingOrder(dto: CreateOrderDto, userId: string) {
    const reservation = await this.reserveInCart(dto, userId);
    const submitted = await this.submitCart(
      { ownerKey: this.ownerKeyFromUser(userId) },
      userId,
    );
    return {
      message: 'Zamówienie przyjęte do weryfikacji',
      quantity: dto.quantity ?? 1,
      product: reservation.product,
      submit: submitted,
    };
  }

  async getReservationSummary(userId: string) {
    await this.cleanupExpiredRejectedReservations(userId);
    const ownerKey = this.ownerKeyFromUser(userId);
    const rows = await this.prisma.productReservation.findMany({
      where: {
        ownerKey,
        status: {
          in: [
            ReservationStatus.IN_CART,
            ReservationStatus.PENDING,
            ReservationStatus.ACCEPTED,
            ReservationStatus.REJECTED,
            ReservationStatus.AUTO_REJECTED,
          ],
        },
      },
      include: {
        product: {
          select: {
            id: true,
            idDotykacka: true,
            name: true,
            price: true,
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
    const grouped = new Map<
      string,
      {
        productId: string;
        idDotykacka: string;
        name: string;
        price: string;
        inCartQty: number;
        pendingQty: number;
        acceptedQty: number;
        rejectedQty: number;
      }
    >();
    for (const row of rows) {
      const key = row.productId;
      const entry = grouped.get(key) ?? {
        productId: row.productId,
        idDotykacka: row.product.idDotykacka,
        name: row.product.name,
        price: row.product.price.toString(),
        inCartQty: 0,
        pendingQty: 0,
        acceptedQty: 0,
        rejectedQty: 0,
      };
      if (row.status === ReservationStatus.IN_CART)
        entry.inCartQty += row.quantity;
      if (row.status === ReservationStatus.PENDING)
        entry.pendingQty += row.quantity;
      if (row.status === ReservationStatus.ACCEPTED)
        entry.acceptedQty += row.quantity;
      if (
        row.status === ReservationStatus.REJECTED ||
        row.status === ReservationStatus.AUTO_REJECTED
      ) {
        entry.rejectedQty += row.quantity;
      }
      grouped.set(key, entry);
    }
    return Array.from(grouped.values());
  }

  async listAddressBook(userId: string) {
    const rows = await this.prisma.addressBookEntry.findMany({
      where: { userId },
      orderBy: [{ isDefault: 'desc' }, { updatedAt: 'desc' }],
    });
    return rows.map((r) => ({
      id: r.id,
      label: r.label,
      entryType: r.entryType,
      recipientName: r.recipientName,
      phone: r.phone,
      email: r.email,
      country: r.country,
      postalCode: r.postalCode,
      city: r.city,
      street: r.street,
      buildingNumber: r.buildingNumber,
      apartmentNumber: r.apartmentNumber,
      parcelLockerId: r.parcelLockerId,
      parcelLockerLabel: r.parcelLockerLabel,
      isDefault: r.isDefault,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    }));
  }

  async upsertAddressBookEntry(userId: string, dto: UpsertAddressBookEntryDto) {
    const shippingMethod =
      dto.entryType === AddressBookEntryType.PARCEL_LOCKER
        ? ShippingMethod.PARCEL_LOCKER_INPOST
        : ShippingMethod.COURIER;
    const normalized = this.normalizeAddressPayload(shippingMethod, dto);
    const entryType =
      dto.entryType ??
      (normalized.parcelLockerId
        ? AddressBookEntryType.PARCEL_LOCKER
        : AddressBookEntryType.ADDRESS);
    if (dto.id) {
      const exists = await this.prisma.addressBookEntry.findFirst({
        where: { id: dto.id, userId },
      });
      if (!exists)
        throw new NotFoundException('Wpis książki adresowej nie istnieje');
      const updated = await this.prisma.$transaction(async (tx) => {
        if (dto.isDefault) {
          await tx.addressBookEntry.updateMany({
            where: { userId },
            data: { isDefault: false },
          });
        }
        return tx.addressBookEntry.update({
          where: { id: dto.id },
          data: {
            label: normalized.label,
            entryType,
            recipientName: normalized.recipientName,
            phone: normalized.phone,
            email: normalized.email,
            country: normalized.country,
            postalCode: normalized.postalCode,
            city: normalized.city,
            street: normalized.street,
            buildingNumber: normalized.buildingNumber,
            apartmentNumber: normalized.apartmentNumber,
            parcelLockerId: normalized.parcelLockerId,
            parcelLockerLabel: normalized.parcelLockerLabel,
            isDefault: dto.isDefault ?? exists.isDefault,
          },
        });
      });
      return updated;
    }
    const created = await this.prisma.$transaction(async (tx) => {
      if (dto.isDefault) {
        await tx.addressBookEntry.updateMany({
          where: { userId },
          data: { isDefault: false },
        });
      }
      return tx.addressBookEntry.create({
        data: {
          userId,
          label: normalized.label,
          entryType,
          recipientName: normalized.recipientName,
          phone: normalized.phone,
          email: normalized.email,
          country: normalized.country,
          postalCode: normalized.postalCode,
          city: normalized.city,
          street: normalized.street,
          buildingNumber: normalized.buildingNumber,
          apartmentNumber: normalized.apartmentNumber,
          parcelLockerId: normalized.parcelLockerId,
          parcelLockerLabel: normalized.parcelLockerLabel,
          isDefault: dto.isDefault ?? false,
        },
      });
    });
    return created;
  }

  async deleteAddressBookEntry(userId: string, id: string) {
    const existing = await this.prisma.addressBookEntry.findFirst({
      where: { userId, id },
      select: { id: true },
    });
    if (!existing)
      throw new NotFoundException('Wpis książki adresowej nie istnieje');
    await this.prisma.addressBookEntry.delete({ where: { id } });
    return { ok: true };
  }

  async getCheckoutPreferences(userId: string) {
    const [pref, defaults] = await Promise.all([
      this.prisma.checkoutPreference.findUnique({ where: { userId } }),
      this.resolveCheckoutDefaults(userId),
    ]);
    return {
      preferredPaymentMethod: pref?.preferredPaymentMethod ?? null,
      preferredShippingMethod: pref?.preferredShippingMethod ?? null,
      preferredAddressId: pref?.preferredAddressId ?? null,
      resolvedDefaults: defaults,
    };
  }

  async updateCheckoutPreferences(
    userId: string,
    dto: UpdateCheckoutPreferencesDto,
  ) {
    if (dto.preferredAddressId) {
      const exists = await this.prisma.addressBookEntry.findFirst({
        where: { id: dto.preferredAddressId, userId },
        select: { id: true },
      });
      if (!exists) {
        throw new NotFoundException('Wybrany domyślny adres nie istnieje');
      }
    }
    const updated = await this.prisma.checkoutPreference.upsert({
      where: { userId },
      create: {
        userId,
        preferredPaymentMethod: dto.preferredPaymentMethod ?? null,
        preferredShippingMethod: dto.preferredShippingMethod ?? null,
        preferredAddressId: dto.preferredAddressId ?? null,
      },
      update: {
        preferredPaymentMethod: dto.preferredPaymentMethod ?? null,
        preferredShippingMethod: dto.preferredShippingMethod ?? null,
        preferredAddressId: dto.preferredAddressId ?? null,
      },
    });
    return updated;
  }

  async getCheckoutOptions(userId: string) {
    const [addressBook, defaults, orders] = await Promise.all([
      this.listAddressBook(userId),
      this.resolveCheckoutDefaults(userId),
      this.prisma.customerOrder.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
    ]);
    const recentTargets = orders
      .map((o) => ({
        paymentMethod: o.paymentMethod,
        shippingMethod: o.shippingMethod,
        shippingTarget: o.shippingSnapshot,
        usedAt: o.createdAt,
      }))
      .filter((o) => o.shippingTarget && typeof o.shippingTarget === 'object');
    const defaultTarget = recentTargets[0]?.shippingTarget as
      | { postalCode?: string; city?: string }
      | undefined;
    const suggestedPickupPoints = await this.shipping.suggestPickupPoints({
      postalCode: defaultTarget?.postalCode,
      city: defaultTarget?.city,
      limit: 8,
    });
    const shippingProviders = this.shipping.listProviders();
    const suggestedInpostPoints = suggestedPickupPoints.INPOST;
    return {
      paymentMethods: Object.values(PaymentMethod),
      shippingMethods: Object.values(ShippingMethod),
      shippingProviders,
      suggestedInpostPoints,
      suggestedPickupPoints,
      addressBook,
      defaults,
      recentTargets,
    };
  }

  async getPaymentForOrder(userId: string, orderId: string) {
    const order = await this.prisma.customerOrder.findFirst({
      where: { id: orderId, userId },
    });
    if (!order) throw new NotFoundException('Zamówienie nie istnieje');
    return {
      orderId: order.id,
      paymentMethod: order.paymentMethod,
      paymentProvider: order.paymentProvider,
      paymentStatus: order.paymentStatus,
      paymentReference: order.paymentReference,
      paymentSessionUrl: order.paymentSessionUrl,
      paymentBankAccount: order.paymentBankAccount,
      paymentDetails: order.paymentDetails,
      totalAmount: order.totalAmount,
      createdAt: order.createdAt,
    };
  }

  async simulatePaymentSuccess(userId: string, orderId: string) {
    const order = await this.prisma.customerOrder.findFirst({
      where: { id: orderId, userId },
      select: { id: true, paymentStatus: true },
    });
    if (!order) throw new NotFoundException('Zamówienie nie istnieje');
    if (order.paymentStatus === PaymentStatus.PAID) {
      return {
        ok: true,
        message: 'Płatność była już wcześniej oznaczona jako opłacona.',
      };
    }
    const updated = await this.prisma.customerOrder.update({
      where: { id: orderId },
      data: {
        paymentStatus: PaymentStatus.PAID,
        paymentDetails: {
          simulatedAt: new Date().toISOString(),
          source: 'dev-simulation',
        },
      },
    });
    return {
      ok: true,
      message: 'Płatność została zaksięgowana w trybie deweloperskim.',
      paymentStatus: updated.paymentStatus,
      orderId: updated.id,
    };
  }

  async finalizeAcceptedOrder(userId: string, dto: FinalizeOrderDto) {
    if (!dto.items || dto.items.length === 0) {
      throw new BadRequestException('Wybierz pozycje do finalizacji');
    }
    const ownerKey = this.ownerKeyFromUser(userId);
    if (!dto.paymentMethod || !dto.shippingMethod) {
      throw new BadRequestException('Wybierz metodę płatności i dostawy.');
    }
    if (!dto.shippingTarget) {
      throw new BadRequestException('Wybierz lub dodaj dane dostawy.');
    }
    const saveToAddressBook = dto.saveToAddressBook ?? true;
    const items = dto.items.filter((i) => i.quantity > 0);
    if (items.length === 0) {
      throw new BadRequestException('Brak ilości > 0 do finalizacji');
    }

    const acceptedRows = await this.prisma.productReservation.findMany({
      where: {
        ownerKey,
        status: ReservationStatus.ACCEPTED,
      },
      include: {
        product: true,
      },
    });
    const byProduct = new Map(acceptedRows.map((r) => [r.productId, r]));

    let subtotal = 0;
    const orderItems = items.map((item) => {
      const row = byProduct.get(item.productId);
      if (!row || row.quantity < item.quantity) {
        throw new ConflictException(
          `Brak wystarczającej ilości zaakceptowanej dla produktu ${item.productId}`,
        );
      }
      const price = Number(row.product.price);
      const lineTotal = price * item.quantity;
      subtotal += lineTotal;
      return {
        productId: row.productId,
        name: row.product.name,
        price: row.product.price,
        quantity: item.quantity,
        lineTotal,
      };
    });

    let discountAmount = new Prisma.Decimal(0);
    let promoId: string | null = null;
    let promoCodeDisplay: string | null = null;
    if (dto.promoCode?.trim()) {
      const pr = await this.promoService.computeDiscountForSubtotal(
        dto.promoCode,
        userId,
        subtotal,
      );
      if (pr) {
        discountAmount = pr.discountAmount;
        promoId = pr.promoId;
        promoCodeDisplay = pr.code;
      }
    }
    const total = Math.round((subtotal - Number(discountAmount)) * 100) / 100;
    if (total < 0) {
      throw new BadRequestException('Kwota zamówienia jest nieprawidłowa.');
    }

    const pickedAddressId =
      dto.shippingTarget.addressBookEntryId?.trim() || null;
    let normalizedShipping: ReturnType<typeof this.normalizeAddressPayload>;
    if (pickedAddressId) {
      const existing = await this.prisma.addressBookEntry.findFirst({
        where: { id: pickedAddressId, userId },
      });
      if (!existing) {
        throw new NotFoundException('Wybrany adres dostawy nie istnieje');
      }
      normalizedShipping = this.normalizeAddressPayload(dto.shippingMethod, {
        label: existing.label ?? undefined,
        recipientName: existing.recipientName ?? undefined,
        phone: existing.phone ?? undefined,
        email: existing.email ?? undefined,
        country: existing.country,
        postalCode: existing.postalCode ?? undefined,
        city: existing.city ?? undefined,
        street: existing.street ?? undefined,
        buildingNumber: existing.buildingNumber ?? undefined,
        apartmentNumber: existing.apartmentNumber ?? undefined,
        parcelLockerId: existing.parcelLockerId ?? undefined,
        parcelLockerLabel: existing.parcelLockerLabel ?? undefined,
      });
    } else {
      normalizedShipping = this.normalizeAddressPayload(
        dto.shippingMethod,
        dto.shippingTarget,
      );
    }

    const paymentInit = await this.payments.initializePayment({
      paymentMethod: dto.paymentMethod,
      totalAmount: total,
      userId,
      orderReference: `ORD-${Date.now()}-${Math.floor(Math.random() * 10000)}`,
    });
    const order = await this.prisma.$transaction(async (tx) => {
      let savedAddressId = pickedAddressId;
      if (!savedAddressId && saveToAddressBook) {
        if (dto.shippingMethod !== ShippingMethod.STORE_PICKUP) {
          const entryType =
            dto.shippingMethod === ShippingMethod.PARCEL_LOCKER_INPOST
              ? AddressBookEntryType.PARCEL_LOCKER
              : AddressBookEntryType.ADDRESS;
          const createdAddress = await tx.addressBookEntry.create({
            data: {
              userId,
              label: normalizedShipping.label,
              entryType,
              recipientName: normalizedShipping.recipientName,
              phone: normalizedShipping.phone,
              email: normalizedShipping.email,
              country: normalizedShipping.country,
              postalCode: normalizedShipping.postalCode,
              city: normalizedShipping.city,
              street: normalizedShipping.street,
              buildingNumber: normalizedShipping.buildingNumber,
              apartmentNumber: normalizedShipping.apartmentNumber,
              parcelLockerId: normalizedShipping.parcelLockerId,
              parcelLockerLabel: normalizedShipping.parcelLockerLabel,
              isDefault: false,
            },
          });
          savedAddressId = createdAddress.id;
        }
      }
      const created = await tx.customerOrder.create({
        data: {
          userId,
          subtotalAmount: new Prisma.Decimal(subtotal.toFixed(2)),
          discountAmount,
          totalAmount: new Prisma.Decimal(total.toFixed(2)),
          promoCodeId: promoId,
          paymentMethod: dto.paymentMethod,
          paymentProvider: paymentInit.paymentProvider,
          paymentStatus: paymentInit.paymentStatus,
          paymentReference: paymentInit.paymentReference,
          paymentSessionUrl: paymentInit.paymentSessionUrl,
          paymentBankAccount: paymentInit.paymentBankAccount,
          paymentDetails: paymentInit.paymentDetails as Prisma.InputJsonValue,
          shippingMethod: dto.shippingMethod,
          shippingSnapshot: {
            ...normalizedShipping,
            addressBookEntryId: savedAddressId,
          },
          saveToAddressBook,
          items: {
            create: orderItems.map((i) => ({
              productId: i.productId,
              name: i.name,
              price: i.price,
              quantity: i.quantity,
              lineTotal: i.lineTotal,
            })),
          },
        },
      });

      if (promoId) {
        await tx.promoRedemption.create({
          data: {
            userId,
            promoCodeId: promoId,
            orderId: created.id,
          },
        });
        await tx.promoCode.update({
          where: { id: promoId },
          data: { usesCount: { increment: 1 } },
        });
      }

      for (const item of items) {
        const row = byProduct.get(item.productId);
        if (!row) continue;
        if (row.quantity === item.quantity) {
          await tx.productReservation.update({
            where: { id: row.id },
            data: { status: ReservationStatus.FINALIZED },
          });
        } else {
          await tx.productReservation.update({
            where: { id: row.id },
            data: { quantity: { decrement: item.quantity } },
          });
          await tx.productReservation.upsert({
            where: {
              ownerKey_productId_status: {
                ownerKey,
                productId: row.productId,
                status: ReservationStatus.FINALIZED,
              },
            },
            create: {
              ownerKey,
              productId: row.productId,
              quantity: item.quantity,
              status: ReservationStatus.FINALIZED,
            },
            update: {
              quantity: { increment: item.quantity },
            },
          });
        }
      }
      return created;
    });

    return {
      id: order.id,
      createdAt: order.createdAt,
      status: order.status,
      subtotalAmount: order.subtotalAmount,
      discountAmount: order.discountAmount,
      totalAmount: order.totalAmount,
      promoCodeId: order.promoCodeId,
      promoCode: promoCodeDisplay,
      paymentMethod: order.paymentMethod,
      paymentProvider: order.paymentProvider,
      paymentStatus: order.paymentStatus,
      paymentReference: order.paymentReference,
      paymentSessionUrl: order.paymentSessionUrl,
      paymentBankAccount: order.paymentBankAccount,
      paymentDetails: order.paymentDetails,
      shippingMethod: order.shippingMethod,
      shippingSnapshot: order.shippingSnapshot,
      items: orderItems.map((i) => ({
        productId: i.productId,
        name: i.name,
        quantity: i.quantity,
        price: i.price,
        lineTotal: i.lineTotal,
      })),
    };
  }

  async watchAvailability(userId: string, productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!product) throw new NotFoundException('Produkt nie istnieje');
    await this.prisma.availabilityWatch.upsert({
      where: {
        userId_productId: {
          userId,
          productId,
        },
      },
      create: {
        userId,
        productId,
      },
      update: {},
    });
    return {
      message:
        'Dziękujemy. Powiadomimy Cię o ponownej dostępności produktu, jeśli wróci do sprzedaży.',
      productId,
    };
  }

  async listAvailabilityWatches(userId: string) {
    const rows = await this.prisma.availabilityWatch.findMany({
      where: { userId },
      include: {
        product: {
          include: {
            reservations: {
              where: {
                status: {
                  in: [ReservationStatus.IN_CART, ReservationStatus.PENDING],
                },
              },
              select: { quantity: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((w) => {
      const reservedQty = w.product.reservations.reduce(
        (sum, r) => sum + r.quantity,
        0,
      );
      const availableQty = Math.max(0, w.product.stockQty - reservedQty);
      return {
        productId: w.productId,
        productName: w.product.name,
        availableNow: availableQty > 0,
        availableQty,
        watchedAt: w.createdAt,
      };
    });
  }

  async listMyNotifications(userId: string) {
    await this.cleanupExpiredRejectedReservations(userId);
    const ownerKey = this.ownerKeyFromUser(userId);
    const reservationRows = await this.prisma.productReservation.findMany({
      where: {
        ownerKey,
        status: {
          in: [
            ReservationStatus.PENDING,
            ReservationStatus.ACCEPTED,
            ReservationStatus.REJECTED,
            ReservationStatus.AUTO_REJECTED,
          ],
        },
      },
      include: {
        product: {
          select: { name: true },
        },
      },
      orderBy: { updatedAt: 'desc' },
      take: 40,
    });
    const orderRows = await this.prisma.customerOrder.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    const watchRows = await this.listAvailabilityWatches(userId);

    const reservationEvents = reservationRows.map((r) => {
      if (r.status === ReservationStatus.PENDING) {
        return {
          type: 'PENDING_APPROVAL',
          level: 'info',
          title: 'Produkt oczekuje na akceptację',
          message:
            'Dziękujemy. Twoja rezerwacja została przyjęta i czeka na potwierdzenie dostępności.',
          productName: r.product.name,
          quantity: r.quantity,
          at: r.updatedAt,
        };
      }
      if (r.status === ReservationStatus.ACCEPTED) {
        return {
          type: 'RESERVATION_ACCEPTED',
          level: 'success',
          title: 'Produkt potwierdzony',
          message:
            'Świetna wiadomość! Produkt jest gotowy do finalizacji zamówienia w koszyku.',
          productName: r.product.name,
          quantity: r.quantity,
          at: r.updatedAt,
        };
      }
      return {
        type: 'RESERVATION_REJECTED',
        level: 'warning',
        title: 'Rezerwacja nie została potwierdzona',
        message:
          'Niestety, ten produkt nie był już dostępny. Pozostanie w koszyku jeszcze przez 15 minut, a potem usuniemy go automatycznie. Powiadomimy Cię, jeśli wróci do sprzedaży.',
        productName: r.product.name,
        quantity: r.quantity,
        at: r.updatedAt,
      };
    });

    const orderEvents = orderRows.map((o) => ({
      type: 'ORDER_PLACED',
      level: 'success',
      title: 'Zamówienie zostało utworzone',
      message:
        'Dziękujemy za zakup. Zamówienie zostało zapisane na Twoim koncie.',
      orderId: o.id,
      totalAmount: o.totalAmount.toString(),
      at: o.createdAt,
    }));

    const watchEvents = watchRows
      .filter((w) => w.availableNow)
      .map((w) => ({
        type: 'BACK_IN_STOCK',
        level: 'info',
        title: 'Produkt ponownie dostępny',
        message:
          'Produkt, który obserwujesz, wrócił do sprzedaży. Możesz dodać go do koszyka.',
        productName: w.productName,
        availableQty: w.availableQty,
        at: w.watchedAt,
      }));

    return [...reservationEvents, ...orderEvents, ...watchEvents].sort(
      (a, b) =>
        new Date(b.at as string | Date).getTime() -
        new Date(a.at as string | Date).getTime(),
    );
  }

  async getMyOrderById(userId: string, orderId: string) {
    const o = await this.prisma.customerOrder.findFirst({
      where: { id: orderId, userId },
      include: {
        items: true,
        promoCode: { select: { code: true, label: true } },
      },
    });
    if (!o) {
      throw new NotFoundException('Zamówienie nie istnieje');
    }
    return {
      id: o.id,
      createdAt: o.createdAt,
      updatedAt: o.updatedAt,
      status: o.status,
      subtotalAmount: o.subtotalAmount.toString(),
      discountAmount: o.discountAmount.toString(),
      totalAmount: o.totalAmount.toString(),
      promoCode: o.promoCode?.code ?? null,
      paymentMethod: o.paymentMethod,
      paymentProvider: o.paymentProvider,
      paymentStatus: o.paymentStatus,
      paymentReference: o.paymentReference,
      paymentSessionUrl: o.paymentSessionUrl,
      paymentBankAccount: o.paymentBankAccount,
      paymentDetails: o.paymentDetails,
      shippingMethod: o.shippingMethod,
      shippingSnapshot: o.shippingSnapshot,
      itemCount: o.items.reduce((sum, i) => sum + i.quantity, 0),
      items: o.items.map((i) => ({
        productId: i.productId,
        name: i.name,
        quantity: i.quantity,
        price: i.price,
        lineTotal: i.lineTotal,
      })),
    };
  }

  async listMyOrders(userId: string) {
    const rows = await this.prisma.customerOrder.findMany({
      where: { userId },
      include: {
        items: true,
        promoCode: { select: { code: true, label: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((o) => ({
      id: o.id,
      createdAt: o.createdAt,
      updatedAt: o.updatedAt,
      status: o.status,
      subtotalAmount: o.subtotalAmount.toString(),
      discountAmount: o.discountAmount.toString(),
      totalAmount: o.totalAmount.toString(),
      promoCode: o.promoCode?.code ?? null,
      paymentMethod: o.paymentMethod,
      paymentProvider: o.paymentProvider,
      paymentStatus: o.paymentStatus,
      paymentReference: o.paymentReference,
      paymentSessionUrl: o.paymentSessionUrl,
      paymentBankAccount: o.paymentBankAccount,
      paymentDetails: o.paymentDetails,
      shippingMethod: o.shippingMethod,
      shippingSnapshot: o.shippingSnapshot,
      itemCount: o.items.reduce((sum, i) => sum + i.quantity, 0),
      items: o.items.map((i) => ({
        productId: i.productId,
        name: i.name,
        quantity: i.quantity,
        price: i.price,
        lineTotal: i.lineTotal,
      })),
    }));
  }

  async listWishlist(userId: string) {
    const rows = await this.prisma.wishlistItem.findMany({
      where: { userId },
      include: {
        product: {
          select: { id: true, name: true, price: true, idDotykacka: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((w) => ({
      id: w.id,
      productId: w.productId,
      name: w.product.name,
      price: w.product.price.toString(),
      idDotykacka: w.product.idDotykacka,
      createdAt: w.createdAt,
    }));
  }

  async addWishlist(userId: string, productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!product) throw new NotFoundException('Produkt nie istnieje');
    await this.prisma.wishlistItem.upsert({
      where: {
        userId_productId: { userId, productId },
      },
      create: { userId, productId },
      update: {},
    });
    return { ok: true, productId };
  }

  async removeWishlist(userId: string, productId: string) {
    await this.prisma.wishlistItem.deleteMany({
      where: { userId, productId },
    });
    return { ok: true };
  }
}
