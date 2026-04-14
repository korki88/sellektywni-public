/** Bezpieczna konwersja wartości z JSON/SOAP na string (unika no-base-to-string przy unknown). */
export function scalarToString(value: unknown): string {
  if (value == null) return '';
  if (typeof value === 'string') return value;
  if (
    typeof value === 'number' ||
    typeof value === 'boolean' ||
    typeof value === 'bigint'
  ) {
    return String(value);
  }
  return '';
}
