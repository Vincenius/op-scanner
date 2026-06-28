import type { CardType } from '@op-scanner/shared';

/**
 * Pure mapping helpers shared across sources. Kept side-effect free so they can
 * be unit-tested directly (variant/alt-art parsing is a tested-where-it-matters
 * area per the project plan).
 */

const CARD_TYPES: readonly CardType[] = [
  'LEADER',
  'CHARACTER',
  'EVENT',
  'STAGE',
  'DON',
];

/** Parse a numeric-ish value ("-", "", null, "2000", 2000) into number | null. */
export function parseNumeric(value: unknown): number | null {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (trimmed === '' || trimmed === '-') return null;
    const n = Number(trimmed.replace(/[^\d.-]/g, ''));
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

/** Empty/whitespace strings become null; otherwise trimmed. */
export function cleanText(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed;
}

/** "Red/Green" -> ["Red","Green"]; "Black" -> ["Black"]; "" -> []. */
export function splitColors(value: unknown): string[] {
  if (typeof value !== 'string') return [];
  return value
    .split('/')
    .map((c) => c.trim())
    .filter((c) => c.length > 0);
}

/** "OP01-077" -> "OP01"; "ST14-001" -> "ST14". */
export function deriveSetCode(cardCode: string): string {
  const dash = cardCode.indexOf('-');
  return dash === -1 ? cardCode : cardCode.slice(0, dash);
}

/** "ROMANCE DAWN [OP-01]" -> "ROMANCE DAWN"; strips a trailing " [..]" tag. */
export function cleanSetName(raw: string): string {
  return raw.replace(/\s*\[[^\]]*\]\s*$/, '').trim() || raw.trim();
}

/** Map an upstream type string to our CardType enum (null if unknown). */
export function mapCardType(value: unknown): CardType | null {
  if (typeof value !== 'string') return null;
  const upper = value.trim().toUpperCase();
  return (CARD_TYPES as readonly string[]).includes(upper)
    ? (upper as CardType)
    : null;
}

/**
 * A printing is an alt-art when the variant id differs from the base code
 * (apitcg encodes parallels as `<code>_pN`). Returns whether it's alt and a
 * human label.
 */
export function variantInfo(variantId: string, cardCode: string): {
  isAltArt: boolean;
  label: string | null;
} {
  if (variantId === cardCode) return { isAltArt: false, label: null };
  const suffix = variantId.slice(cardCode.length).replace(/^_/, '');
  const parallel = /^p(\d+)$/i.exec(suffix);
  if (parallel) {
    const n = Number(parallel[1]);
    return { isAltArt: true, label: n > 1 ? `Parallel ${n}` : 'Parallel' };
  }
  return { isAltArt: true, label: suffix ? suffix.toUpperCase() : 'Alt Art' };
}
