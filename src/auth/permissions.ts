import { ProfileRole } from '@prisma/client';

export const PermissionKeys = {
  manageReservations: 'manage.reservations',
  manageCustomers: 'manage.customers',
  manageOrders: 'manage.orders',
  manageDotykacka: 'manage.dotykacka',
  managePermissions: 'manage.permissions',
  viewAnalytics: 'view.analytics',
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
    ];
  }
  return [];
}
