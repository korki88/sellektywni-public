import { SetMetadata } from '@nestjs/common';

export const AUDIT_ACTION_KEY = 'audit_action';
export const AUDIT_RESOURCE_PARAM_KEY = 'audit_resource_param';
export const AUDIT_RESOURCE_TYPE_KEY = 'audit_resource_type';
export const AUDIT_MANUAL_KEY = 'audit_manual';

/** Nadpisuje domyślną nazwę akcji logowanej przez interceptor audytu. */
export const AuditAction = (action: string) =>
  SetMetadata(AUDIT_ACTION_KEY, action);

/** Wskazuje nazwę parametru, który ma trafić do resourceId (np. id, userId). */
export const AuditResourceParam = (paramName: string) =>
  SetMetadata(AUDIT_RESOURCE_PARAM_KEY, paramName);

/** Wskazuje domenę obiektu biznesowego (ORDER, PRODUCT, CUSTOMER, ...). */
export const AuditResourceType = (resourceType: string) =>
  SetMetadata(AUDIT_RESOURCE_TYPE_KEY, resourceType);

/** Oznacza endpoint, dla którego log powstaje ręcznie w serwisie domenowym. */
export const AuditManual = () => SetMetadata(AUDIT_MANUAL_KEY, true);
