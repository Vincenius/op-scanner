import type { CardSource } from '../sources/types.js';
import { upsertCatalog, upsertPrices } from './upsert.js';

export interface IngestConfig {
  /** Owns sets + cards + variants. */
  metadata: CardSource;
  /** Owns prices. May be the same instance as `metadata`. */
  prices: CardSource;
}

/** Run a full ingest: catalog from the metadata source, prices from the price source. */
export async function runIngest(config: IngestConfig): Promise<void> {
  const { metadata, prices } = config;

  console.log(`[ingest] metadata source: ${metadata.id}, price source: ${prices.id}`);

  console.log('[ingest] fetching sets + cards...');
  const [sets, cards] = await Promise.all([
    metadata.fetchSets(),
    metadata.fetchCards(),
  ]);
  console.log(`[ingest] fetched ${sets.length} sets, ${cards.length} cards`);

  console.log('[ingest] upserting catalog...');
  const catalogStats = await upsertCatalog(sets, cards);
  console.log(
    `[ingest] catalog: ${catalogStats.sets} sets, ${catalogStats.cards} cards, ${catalogStats.variants} variants`,
  );

  console.log('[ingest] fetching prices...');
  const priceRows = await prices.fetchPrices();
  console.log(`[ingest] fetched ${priceRows.length} price rows`);

  const priceStats = await upsertPrices(priceRows);
  console.log(
    `[ingest] prices: ${priceStats.written} written, ${priceStats.skipped} skipped (unknown variants)`,
  );

  console.log('[ingest] done.');
}
