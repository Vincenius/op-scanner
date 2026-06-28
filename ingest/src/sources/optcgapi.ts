import { fetchJson, sleep } from '../http.js';
import { parseNumeric } from '../mapping.js';
import type { CardSource, RawCard, RawPrice, RawSet } from './types.js';

interface OptcgSet {
  set_name: string;
  set_id: string; // "OP-01"
}

interface OptcgPriceRow {
  card_set_id: string; // base code, "OP01-077"
  card_image_id: string; // variant id, "OP01-077" or "OP01-077_p1"  <-- maps to our variantId
  rarity?: string;
  market_price?: number | string | null;
  inventory_price?: number | string | null;
  date_scraped?: string; // "2026-06-28"
}

const DEFAULT_BASE = 'https://optcgapi.com/api';

/** Parse "2026-06-28" to a UTC-midnight Date; falls back to now. */
function parseCapturedAt(dateScraped: string | undefined): string {
  if (dateScraped && /^\d{4}-\d{2}-\d{2}$/.test(dateScraped)) {
    return new Date(`${dateScraped}T00:00:00.000Z`).toISOString();
  }
  return new Date().toISOString();
}

/**
 * optcgapi.com price source — TCGPlayer USD market prices keyed by
 * `card_image_id` (== our variantId, alt-arts included). Used as a PRICE source
 * only; it does not own sets/cards in the pipeline.
 */
export class OptcgApiSource implements CardSource {
  readonly id = 'optcgapi';
  private readonly baseUrl: string;

  constructor(opts: { baseUrl?: string } = {}) {
    this.baseUrl = opts.baseUrl ?? DEFAULT_BASE;
  }

  async fetchSets(): Promise<RawSet[]> {
    return [];
  }

  async fetchCards(): Promise<RawCard[]> {
    return [];
  }

  async fetchPrices(): Promise<RawPrice[]> {
    const sets = await fetchJson<OptcgSet[]>(`${this.baseUrl}/allSets/`);
    const prices: RawPrice[] = [];
    for (const set of sets) {
      let rows: OptcgPriceRow[];
      try {
        rows = await fetchJson<OptcgPriceRow[]>(
          `${this.baseUrl}/sets/${set.set_id}/`,
        );
      } catch (err) {
        console.warn(`[optcgapi] skipping set ${set.set_id}: ${String(err)}`);
        continue;
      }
      for (const row of rows) {
        const variantId = row.card_image_id || row.card_set_id;
        if (!variantId) continue;
        prices.push({
          variantId,
          source: 'tcgplayer',
          currency: 'USD',
          marketPrice: parseNumeric(row.market_price) ?? undefined,
          lowPrice: parseNumeric(row.inventory_price) ?? undefined,
          capturedAt: parseCapturedAt(row.date_scraped),
        });
      }
      await sleep(300); // rate-limit friendly
    }
    return prices;
  }
}
