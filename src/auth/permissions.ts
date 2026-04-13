import { ProfileRole } from '@prisma/client';

export const PermissionKeys = {
  manageReservations: 'manage.reservations',
  manageCustomers: 'manage.customers',
  manageOrders: 'manage.orders',
  manageDotykacka: 'manage.dotykacka',
  managePermissions: 'manage.permissions',
  viewAnalytics: 'view.analytics',
  /** Strony CMS (regulamin, treści). */
  manageCms: 'manage.cms',
  /** Zgłoszenia helpdesk. */
  manageSupport: 'manage.support',
  /** Eksperymenty A/B. */
  manageExperiments: 'manage.experiments',
  /** Karty podarunkowe. */
  manageGiftCards: 'manage.gift_cards',
  /** Merchandising: polecane, podtytuły produktów. */
  manageCatalog: 'manage.catalog',
  /** Moderacja opinii produktów. */
  manageReviews: 'manage.reviews',
} as const;

export const AllPermissionValues = Object.values(PermissionKeys);

export function defaultPermissionsForRole(role: ProfileRole): string[] {
  if (role === ProfileRole.OWNER) {
    return [...AllPermissionValues];
  }
  if (role === ProfileRole.STAFF) {
    return [
      PermissionKeys.manageReservations,
      PermissionKeys.manageCustomers,
      PermissionKeys.manageOrders,
      PermissionKeys.manageDotykacka,
      PermissionKeys.manageCms,
      PermissionKeys.manageSupport,
      PermissionKeys.manageCatalog,
      PermissionKeys.manageReviews,
    ];
  }
  return [];
}
