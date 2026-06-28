/**
 * Shared types between the server and the ingestion module — and the source
 * of truth for the generated Dart models used by the Flutter client.
 *
 * Phase 1 will generate the API DTOs from the Fastify OpenAPI schema and emit
 * the matching Dart models into the client. For Phase 0 this is a minimal
 * placeholder so the workspace wiring (and the `@op-scanner/shared` import
 * path) is in place and verifiable.
 */

export const SHARED_SCHEMA_VERSION = '0.0.0';

/** Card supertype. Mirrors the Prisma `CardType` enum on the server. */
export type CardType = 'LEADER' | 'CHARACTER' | 'EVENT' | 'STAGE' | 'DON';

/** Card condition grades. Mirrors the Prisma `CardCondition` enum. */
export type CardCondition = 'NM' | 'LP' | 'MP' | 'HP' | 'DMG';

/** Known pricing sources. Kept open (string) on the DB side so new
 *  marketplaces can be ingested without a migration. */
export type PriceSource = 'tcgplayer' | 'cardmarket';
