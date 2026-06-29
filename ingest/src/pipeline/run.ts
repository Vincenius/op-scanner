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

  // Gap-fill the catalog from the price source for any sets/cards the metadata
  // source doesn't carry yet. apitcg lags behind on the newest sets (it stopped
  // at OP12 while optcgapi already lists OP13–OP16), so those sets would
  // otherwise never enter the catalog and their prices would be skipped. The
  // metadata source stays authoritative wherever it has the card; the price
  // source only contributes what's missing (and is overwritten on a later run
  // once the metadata source catches up).
  let mergedSets = sets;
  let mergedCards = cards;
  if (prices !== metadata) {
    const [pSets, pCards] = await Promise.all([
      prices.fetchSets(),
      prices.fetchCards(),
    ]);
    const haveCards = new Set(cards.map((c) => c.cardCode));
    const haveSets = new Set(sets.map((s) => s.code));
    const extraCards = pCards.filter((c) => !haveCards.has(c.cardCode));
    const extraSets = pSets.filter((s) => !haveSets.has(s.code));
    if (extraCards.length || extraSets.length) {
      mergedSets = [...sets, ...extraSets];
      mergedCards = [...cards, ...extraCards];
      console.log(
        `[ingest] catalog gap-fill from ${prices.id}: +${extraSets.length} sets, +${extraCards.length} cards (${extraSets.map((s) => s.code).join(', ')})`,
      );
    }
  }

  console.log('[ingest] upserting catalog...');
  const catalogStats = await upsertCatalog(mergedSets, mergedCards);
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
