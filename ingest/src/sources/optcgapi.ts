import { fetchJson, sleep } from '../http.js';
import {
  cleanText,
  deriveSetCode,
  mapCardType,
  parseNumeric,
  splitColors,
  variantInfo,
} from '../mapping.js';
import type { CardSource, RawCard, RawPrice, RawSet, RawVariant } from './types.js';

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
  // Catalog metadata (present on every row; used to gap-fill sets/cards the
  // primary metadata source doesn't carry yet).
  card_name?: string;
  set_name?: string;
  card_color?: string; // space-separated dual colors, e.g. "Red Black"
  card_type?: string; // "Character" | "Leader" | "Event" | "Stage"
  card_cost?: number | string | null;
  card_power?: number | string | null;
  counter_amount?: number | string | null;
  attribute?: string | null;
  sub_types?: string | null;
  card_text?: string | null;
  card_image?: string | null;
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
 * optcgapi.com source — TCGPlayer USD market prices keyed by `card_image_id`
 * (== our variantId, alt-arts included). Primarily a PRICE source, but every
 * price row also carries full card metadata, so it can act as a catalog
 * gap-filler for sets the metadata source (apitcg) hasn't published yet — the
 * newest OP sets land on optcgapi well before apitcg lists them. A single crawl
 * feeds both {@link fetchPrices} and {@link fetchCards}/{@link fetchSets}.
 */
export class OptcgApiSource implements CardSource {
  readonly id = 'optcgapi';
  private readonly baseUrl: string;
  private cache: OptcgPriceRow[] | null = null;

  constructor(opts: { baseUrl?: string } = {}) {
    this.baseUrl = opts.baseUrl ?? DEFAULT_BASE;
  }

  /** Crawl every set's rows once (cached); shared by prices + catalog. */
  private async loadAll(): Promise<OptcgPriceRow[]> {
    if (this.cache) return this.cache;
    const sets = await fetchJson<OptcgSet[]>(`${this.baseUrl}/allSets/`);
    const rows: OptcgPriceRow[] = [];
    for (const set of sets) {
      try {
        const setRows = await fetchJson<OptcgPriceRow[]>(
          `${this.baseUrl}/sets/${set.set_id}/`,
        );
        rows.push(...setRows);
      } catch (err) {
        console.warn(`[optcgapi] skipping set ${set.set_id}: ${String(err)}`);
      }
      await sleep(300); // rate-limit friendly
    }
    this.cache = rows;
    return rows;
  }

  async fetchSets(): Promise<RawSet[]> {
    const rows = await this.loadAll();
    // One set per card-code prefix; display name = the most common set_name seen
    // for that prefix (set endpoints can bundle reprints from other sets).
    const nameCounts = new Map<string, Map<string, number>>();
    for (const r of rows) {
      const base = r.card_set_id || r.card_image_id;
      if (!base) continue;
      const code = deriveSetCode(base);
      const name = cleanText(r.set_name) ?? code;
      const counts = nameCounts.get(code) ?? new Map<string, number>();
      counts.set(name, (counts.get(name) ?? 0) + 1);
      nameCounts.set(code, counts);
    }
    const sets: RawSet[] = [];
    for (const [code, counts] of nameCounts) {
      let bestName = code;
      let bestCount = -1;
      for (const [name, count] of counts) {
        if (count > bestCount) {
          bestName = name;
          bestCount = count;
        }
      }
      sets.push({ code, name: bestName });
    }
    return sets;
  }

  async fetchCards(): Promise<RawCard[]> {
    const rows = await this.loadAll();
    // Group rows by base card code (card_set_id); each card_image_id is a variant.
    const groups = new Map<string, OptcgPriceRow[]>();
    for (const r of rows) {
      const code = r.card_set_id;
      if (!code) continue;
      const list = groups.get(code) ?? [];
      list.push(r);
      groups.set(code, list);
    }

    const cards: RawCard[] = [];
    for (const [code, group] of groups) {
      const base =
        group.find((r) => (r.card_image_id || r.card_set_id) === code) ?? group[0];
      if (!base) continue;
      const type = mapCardType(base.card_type);
      if (!type) {
        console.warn(`[optcgapi] skipping ${code}: unknown type "${base.card_type ?? ''}"`);
        continue;
      }
      // Dedup variants by id: the same printing can recur across set endpoints
      // (reprint bundles like OP14-EB04).
      const seen = new Set<string>();
      const variants: RawVariant[] = [];
      for (const r of group) {
        const variantId = r.card_image_id || r.card_set_id;
        if (!variantId || seen.has(variantId)) continue;
        seen.add(variantId);
        const info = variantInfo(variantId, code);
        variants.push({
          variantId,
          rarity: cleanText(r.rarity) ?? undefined,
          isAltArt: info.isAltArt,
          variantLabel: info.label ?? undefined,
          imageThumbUrl: cleanText(r.card_image) ?? undefined,
          imageFullUrl: cleanText(r.card_image) ?? undefined,
        });
      }
      cards.push({
        cardCode: code,
        setCode: deriveSetCode(code),
        name: cleanText(base.card_name) ?? code,
        colors: splitColors(base.card_color),
        type,
        cost: parseNumeric(base.card_cost) ?? undefined,
        power: parseNumeric(base.card_power) ?? undefined,
        counter: parseNumeric(base.counter_amount) ?? undefined,
        attribute: cleanText(base.attribute) ?? undefined,
        family: cleanText(base.sub_types) ?? undefined,
        abilityText: cleanText(base.card_text) ?? undefined,
        triggerText: undefined, // optcgapi folds triggers into card_text
        variants,
      });
    }
    return cards;
  }

  async fetchPrices(): Promise<RawPrice[]> {
    const rows = await this.loadAll();
    const prices: RawPrice[] = [];
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
    return prices;
  }
}
