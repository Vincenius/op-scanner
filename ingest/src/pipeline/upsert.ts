import { prisma } from '../db.js';
import type { RawCard, RawPrice, RawSet } from '../sources/types.js';
import { deriveSetCode } from '../mapping.js';
import { mapLimit } from './concurrency.js';

export interface CatalogStats {
  sets: number;
  cards: number;
  variants: number;
}

/**
 * Upsert sets, cards, and variants. Idempotent: keyed by set.code,
 * card.cardCode, and variant.variantId. One row per printing (alt-arts
 * included). Never writes phash (owned by the Phase 3 precompute step).
 */
export async function upsertCatalog(
  sets: RawSet[],
  cards: RawCard[],
): Promise<CatalogStats> {
  // 1) Sets -> code->id map. Include any set codes referenced by cards but
  //    missing from the sets list (defensive).
  const setCodes = new Map<string, RawSet>();
  for (const s of sets) setCodes.set(s.code, s);
  for (const c of cards) {
    const code = c.setCode || deriveSetCode(c.cardCode);
    if (!setCodes.has(code)) setCodes.set(code, { code, name: code });
  }

  const setIdByCode = new Map<string, string>();
  for (const s of setCodes.values()) {
    const row = await prisma.set.upsert({
      where: { code: s.code },
      create: {
        code: s.code,
        name: s.name,
        releaseDate: s.releaseDate ? new Date(s.releaseDate) : null,
      },
      update: {
        name: s.name,
        ...(s.releaseDate ? { releaseDate: new Date(s.releaseDate) } : {}),
      },
    });
    setIdByCode.set(s.code, row.id);
  }

  // 2) Cards + their variants (parallel across cards; variants sequential
  //    within a card since they need the card id first).
  let variantCount = 0;
  await mapLimit(cards, 16, async (c) => {
    const setId = setIdByCode.get(c.setCode || deriveSetCode(c.cardCode));
    if (!setId) return;
    const card = await prisma.card.upsert({
      where: { cardCode: c.cardCode },
      create: {
        cardCode: c.cardCode,
        name: c.name,
        colors: c.colors,
        type: c.type,
        cost: c.cost,
        power: c.power,
        counter: c.counter,
        attribute: c.attribute,
        family: c.family,
        abilityText: c.abilityText,
        triggerText: c.triggerText,
        setId,
      },
      update: {
        name: c.name,
        colors: c.colors,
        type: c.type,
        cost: c.cost,
        power: c.power,
        counter: c.counter,
        attribute: c.attribute,
        family: c.family,
        abilityText: c.abilityText,
        triggerText: c.triggerText,
        setId,
      },
    });
    for (const v of c.variants) {
      await prisma.cardVariant.upsert({
        where: { variantId: v.variantId },
        create: {
          variantId: v.variantId,
          cardId: card.id,
          rarity: v.rarity,
          isAltArt: v.isAltArt,
          variantLabel: v.variantLabel,
          imageThumbUrl: v.imageThumbUrl,
          imageFullUrl: v.imageFullUrl,
        },
        update: {
          cardId: card.id,
          rarity: v.rarity,
          isAltArt: v.isAltArt,
          variantLabel: v.variantLabel,
          imageThumbUrl: v.imageThumbUrl,
          imageFullUrl: v.imageFullUrl,
        },
      });
      variantCount++;
    }
  });

  return { sets: setIdByCode.size, cards: cards.length, variants: variantCount };
}

/**
 * Upsert prices (append-only across captures; idempotent per
 * variant/source/currency/capturedAt). Prices for unknown variants are skipped
 * so a price-source/metadata-source mismatch can't break ingestion.
 */
export async function upsertPrices(prices: RawPrice[]): Promise<{ written: number; skipped: number }> {
  const known = new Set(
    (await prisma.cardVariant.findMany({ select: { variantId: true } })).map(
      (v) => v.variantId,
    ),
  );
  const applicable = prices.filter((p) => known.has(p.variantId));
  const skipped = prices.length - applicable.length;

  await mapLimit(applicable, 16, async (p) => {
    const capturedAt = new Date(p.capturedAt);
    await prisma.price.upsert({
      where: {
        variantId_source_currency_capturedAt: {
          variantId: p.variantId,
          source: p.source,
          currency: p.currency,
          capturedAt,
        },
      },
      create: {
        variantId: p.variantId,
        source: p.source,
        currency: p.currency,
        marketPrice: p.marketPrice,
        lowPrice: p.lowPrice,
        capturedAt,
      },
      update: {
        marketPrice: p.marketPrice,
        lowPrice: p.lowPrice,
      },
    });
  });

  return { written: applicable.length, skipped };
}
