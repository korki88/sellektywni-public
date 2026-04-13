/** Jednolita normalizacja kodów promocyjnych (porównania w DB). */
export function normalizePromoCode(raw: string): string {
  return raw.trim().toUpperCase();
}
