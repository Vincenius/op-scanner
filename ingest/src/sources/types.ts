/**
 * Pluggable card-data source interface.
 *
 * The ingestion job is intentionally decoupled from the user-facing API so the
 * upstream source can be swapped (apitcg.com, optcgapi.com, a self-hosted
 * optcg-api clone, ...) without touching the rest of the system. Every concrete
 * source implements {@link CardSource}; the ingest pipeline consumes the `Raw*`
 * shapes and maps them onto the Prisma catalog models.
 *
 * IMPORTANT (alt-art correctness): `fetchCards()` MUST return every printing of
 * a card code as a distinct {@link RawCard} entry. The same printed code (e.g.
 * `OP03-070`) can have a base, parallel/alt-art, manga-rare, etc. printing —
 * each becomes its own `card_variant` row with a stable `variantId`
 * (`OP03-070`, `OP03-070_p1`, `OP03-070_aa`, ...). The recognizer and pricing
 * both operate at the variant level.
 */

import type { CardType } from '@op-scanner/shared';

export interface RawSet {
  /** Set code, e.g. "OP03", "ST01", "EB01". */
  code: string;
  name: string;
  /** ISO-8601 date string if known. */
  releaseDate?: string;
}

export interface RawVariant {
  /** Stable variant id, e.g. "OP03-070", "OP03-070_p1", "OP03-070_aa". */
  variantId: string;
  rarity?: string;
  isAltArt: boolean;
  /** Human label, e.g. "Parallel", "Manga", "Box Topper". */
  variantLabel?: string;
  imageThumbUrl?: string;
  imageFullUrl?: string;
}

export interface RawCard {
  /** Base printed card code, e.g. "OP03-070". */
  cardCode: string;
  setCode: string;
  name: string;
  colors: string[];
  type: CardType;
  cost?: number;
  power?: number;
  counter?: number;
  attribute?: string;
  family?: string;
  abilityText?: string;
  triggerText?: string;
  /** Every distinct printing of this card code. */
  variants: RawVariant[];
}

export interface RawPrice {
  variantId: string;
  /** e.g. "tcgplayer", "cardmarket". */
  source: string;
  /** ISO-4217, e.g. "USD", "EUR". */
  currency: string;
  marketPrice?: number;
  lowPrice?: number;
  /** ISO-8601 timestamp the price was captured. */
  capturedAt: string;
}

export interface CardSource {
  /** Identifier for logs / provenance, e.g. "apitcg". */
  readonly id: string;
  fetchSets(): Promise<RawSet[]>;
  /** Must include every variant / alt-art as a distinct entry. */
  fetchCards(setCode?: string): Promise<RawCard[]>;
  /** Keyed by variant + source + currency. */
  fetchPrices(): Promise<RawPrice[]>;
}
