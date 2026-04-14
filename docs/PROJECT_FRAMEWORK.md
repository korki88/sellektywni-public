# SELLEKTYWNI.PL - Project Framework (Operational Baseline)

This document defines the mandatory operating framework for all future implementation tasks.

## Access Architecture (Omnichannel)

- Single backend: NestJS.
- Single frontend project: Flutter.
- Roles:
  - `OWNER` - full access.
  - `STAFF` - reservations, scanner, loyalty operations.
  - `CUSTOMER` - shopping experience.
- Administrative interfaces:
  - `Unified Admin Dashboard` (WWW/App).
  - `Staff Sidebar` (Android overlay).

## Naming and Consistency Rules

Use only the following terms in code/docs/features:

- `Staff Sidebar`
- `Owner Dashboard`
- `Customer App`

Every administrative feature must:

1. Be protected by `RolesGuard`.
2. Be logged into `AuditLog`.

## POS Integration (Dotykačka)

- Dotykačka is the primary source of stock truth.
- Online reservations must use status `PENDING_APPROVAL`.
- `PENDING_APPROVAL` reservations require manual acceptance in `Staff Sidebar`.

## IDE and Delivery Rules

- After each significant change or completed plan step, create a `git commit`.
- Always evaluate margin/profit impact for changes touching `Product` pricing/cost logic.
- Keep Prisma on version `6.19.3`.
- Do not upgrade to Prisma v7 without explicit approval.

## Business Goal Priority

Primary objective: financial liquidity and AI-driven marketing automation through:

- `Profit Guard`
- `Hype Maker`

