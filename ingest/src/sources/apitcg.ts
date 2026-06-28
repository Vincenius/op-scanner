import { fetchJson, sleep } from '../http.js';
import {
  cleanSetName,
  cleanText,
  deriveSetCode,
  mapCardType,
  parseNumeric,
  splitColors,
  variantInfo,
} from '../mapping.js';
import type { CardSource, RawCard, RawPrice, RawSet, RawVariant } from './types.js';

/** Shape of a single apitcg One Piece card entry (one per printing/variant). */
export interface ApiTcgEntry {
  id: string; // variant id, e.g. "OP01-077" or "OP01-077_p1"
  code: string; // base card code, e.g. "OP01-077"
  rarity?: string;
  type?: string;
  name?: string;
  images?: { small?: string; large?: string };
  cost?: number | string | null;
  attribute?: { name?: string } | null;
  power?: number | string | null;
  counter?: number | string | null;
  color?: string;
  family?: string;
  ability?: string;
  trigger?: string;
  set?: { name?: string };
}

interface ApiTcgPage {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  data: ApiTcgEntry[];
}

const DEFAULT_BASE = 'https://www.apitcg.com/api/one-piece';

/** Pure: derive distinct sets from a flat list of apitcg entries. */
export function entriesToSets(entries: ApiTcgEntry[]): RawSet[] {
  const byCode = new Map<string, RawSet>();
  for (const e of entries) {
    const code = deriveSetCode(e.code);
    if (!byCode.has(code)) {
      byCode.set(code, { code, name: e.set?.name ? cleanSetName(e.set.name) : code });
    }
  }
  return [...byCode.values()];
}

/** Pure: group apitcg entries (one per printing) into cards with variants. */
export function entriesToCards(entries: ApiTcgEntry[]): RawCard[] {
  const groups = new Map<string, ApiTcgEntry[]>();
  for (const e of entries) {
    const list = groups.get(e.code) ?? [];
    list.push(e);
    groups.set(e.code, list);
  }

  const cards: RawCard[] = [];
  for (const [code, group] of groups) {
    const base = group.find((e) => e.id === e.code) ?? group[0];
    if (!base) continue;
    const type = mapCardType(base.type);
    if (!type) {
      console.warn(`[apitcg] skipping ${code}: unknown type "${base.type ?? ''}"`);
      continue;
    }
    const variants: RawVariant[] = group.map((e) => {
      const info = variantInfo(e.id, e.code);
      return {
        variantId: e.id,
        rarity: cleanText(e.rarity) ?? undefined,
        isAltArt: info.isAltArt,
        variantLabel: info.label ?? undefined,
        imageThumbUrl: e.images?.small,
        imageFullUrl: e.images?.large,
      };
    });
    cards.push({
      cardCode: code,
      setCode: deriveSetCode(code),
      name: cleanText(base.name) ?? code,
      colors: splitColors(base.color),
      type,
      cost: parseNumeric(base.cost) ?? undefined,
      power: parseNumeric(base.power) ?? undefined,
      counter: parseNumeric(base.counter) ?? undefined,
      attribute: cleanText(base.attribute?.name) ?? undefined,
      family: cleanText(base.family) ?? undefined,
      abilityText: cleanText(base.ability) ?? undefined,
      triggerText: cleanText(base.trigger) ?? undefined,
      variants,
    });
  }
  return cards;
}

/**
 * apitcg.com metadata + image source. Returns every printing as a distinct
 * variant (alt-arts included). Provides NO pricing (One Piece prices come from
 * the price source).
 */
export class ApiTcgSource implements CardSource {
  readonly id = 'apitcg';
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly pageLimit: number;
  private cache: ApiTcgEntry[] | null = null;

  constructor(opts: { apiKey: string; baseUrl?: string; pageLimit?: number }) {
    if (!opts.apiKey) throw new Error('ApiTcgSource requires an API key (APITCG_API_KEY)');
    this.apiKey = opts.apiKey;
    this.baseUrl = opts.baseUrl ?? DEFAULT_BASE;
    this.pageLimit = opts.pageLimit ?? 100;
  }

  private async loadAll(): Promise<ApiTcgEntry[]> {
    if (this.cache) return this.cache;
    const headers = { 'x-api-key': this.apiKey };
    const first = await fetchJson<ApiTcgPage>(
      `${this.baseUrl}/cards?page=1&limit=${this.pageLimit}`,
      { headers },
    );
    const entries = [...first.data];
    for (let page = 2; page <= first.totalPages; page++) {
      const res = await fetchJson<ApiTcgPage>(
        `${this.baseUrl}/cards?page=${page}&limit=${this.pageLimit}`,
        { headers },
      );
      entries.push(...res.data);
      await sleep(150); // be polite
    }
    this.cache = entries;
    return entries;
  }

  async fetchSets(): Promise<RawSet[]> {
    return entriesToSets(await this.loadAll());
  }

  async fetchCards(): Promise<RawCard[]> {
    return entriesToCards(await this.loadAll());
  }

  // apitcg has no One Piece pricing.
  async fetchPrices(): Promise<RawPrice[]> {
    return [];
  }
}
