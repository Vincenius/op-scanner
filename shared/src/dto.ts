/**
 * API DTOs — the contract between the server and clients. The Flutter client
 * mirrors these shapes (hand-authored Dart models for now; a later step can
 * generate them from the Fastify OpenAPI output).
 */
import type { CardCondition, CardType } from './index.js';

export interface SetDto {
  id: string;
  code: string;
  name: string;
  releaseDate: string | null; // ISO date
}

export interface PriceDto {
  source: string; // 'tcgplayer' | ...
  currency: string; // 'USD' | ...
  marketPrice: number | null;
  lowPrice: number | null;
  capturedAt: string; // ISO timestamp
}

export interface VariantDto {
  variantId: string;
  cardId: string;
  rarity: string | null;
  isAltArt: boolean;
  variantLabel: string | null;
  /** Stable proxy paths (relative to the API base); upstream URLs stay server-side. */
  thumbUrl: string; // e.g. /img/variants/OP01-016_p1/thumb
  fullUrl: string;
  /** RGB perceptual hash for on-device recognition (48 hex), null until precomputed. */
  phash: string | null;
  /** Latest price (per the default source/currency), if known. */
  currentPrice: PriceDto | null;
}

export interface CardDto {
  id: string;
  cardCode: string;
  name: string;
  colors: string[];
  type: CardType;
  cost: number | null;
  power: number | null;
  counter: number | null;
  attribute: string | null;
  family: string | null;
  abilityText: string | null;
  triggerText: string | null;
  setId: string;
  setCode: string;
  variants: VariantDto[];
}

/** Response of GET /catalog/sync?since=. */
export interface CatalogSyncResponse {
  /** Server time of this response; pass back as `since` on the next sync. */
  serverTime: string;
  /** Whether this was a full snapshot (since omitted) vs a delta. */
  full: boolean;
  sets: SetDto[];
  cards: CardDto[];
}

/** Response of GET /cards (paginated). */
export interface PagedCards {
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
  data: CardDto[];
}

// --- Auth ---

export interface UserDto {
  id: string;
  email: string;
}

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresIn: number; // seconds
  user: UserDto;
}

// --- Tags ---

export interface TagDto {
  clientUuid: string;
  name: string;
  color: string | null;
  updatedAt: string;
  deletedAt: string | null;
}

export interface TagMutation {
  clientUuid: string;
  name: string;
  color: string | null;
  updatedAt: string;
  deleted: boolean;
}

// --- Collection ---

/** A single offline mutation sent to POST /collection/sync. */
export interface CollectionMutation {
  clientUuid: string;
  variantId: string;
  quantity: number;
  condition: CardCondition;
  isFoil: boolean;
  notes: string | null;
  /** Tags assigned to this entry (by tag clientUuid). Replaces the entry's set. */
  tagClientUuids: string[];
  updatedAt: string; // client logical timestamp (ISO) — LWW basis
  deleted: boolean;
}

/** Authoritative collection item (lean sync shape). */
export interface CollectionItemDto {
  clientUuid: string;
  variantId: string;
  quantity: number;
  condition: CardCondition;
  isFoil: boolean;
  notes: string | null;
  tagClientUuids: string[];
  updatedAt: string;
  deletedAt: string | null;
  addedAt: string;
}

export interface CollectionSyncRequest {
  /** Pull authoritative items/tags changed since this time (omit for all). */
  since?: string;
  tags?: TagMutation[];
  mutations: CollectionMutation[];
}

export interface CollectionSyncResponse {
  serverTime: string;
  tags: TagDto[];
  items: CollectionItemDto[];
}

/** Rich collection entry for GET /collection (joined with catalog + price). */
export interface CollectionEntryDto extends CollectionItemDto {
  card: { id: string; name: string; cardCode: string; setCode: string; colors: string[]; type: CardType };
  variant: { rarity: string | null; isAltArt: boolean; variantLabel: string | null; thumbUrl: string };
  currentPrice: PriceDto | null;
  tags: { clientUuid: string; name: string; color: string | null }[];
}
