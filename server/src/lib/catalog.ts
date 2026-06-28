import type { Prisma, PrismaClient } from '@prisma/client';
import type { CardDto, PriceDto } from '@op-scanner/shared';
import { toCardDto, toPriceDto, type CardWithVariants } from './mappers.js';

export const DEFAULT_PRICE_SOURCE = 'tcgplayer';
export const DEFAULT_PRICE_CURRENCY = 'USD';

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

/** Latest price per variant for the default source/currency. */
export async function currentPriceMap(
  prisma: PrismaClient,
  variantIds: string[],
  source = DEFAULT_PRICE_SOURCE,
  currency = DEFAULT_PRICE_CURRENCY,
): Promise<Map<string, PriceDto>> {
  const map = new Map<string, PriceDto>();
  for (const ids of chunk(variantIds, 1000)) {
    const rows = await prisma.price.findMany({
      where: { variantId: { in: ids }, source, currency },
      orderBy: { capturedAt: 'desc' },
    });
    for (const row of rows) {
      if (!map.has(row.variantId)) map.set(row.variantId, toPriceDto(row));
    }
  }
  return map;
}

/** Hydrate cards (with variants + current price) into DTOs, sorted by code. */
export async function loadCards(
  prisma: PrismaClient,
  where: Prisma.CardWhereInput,
): Promise<CardDto[]> {
  const cards = (await prisma.card.findMany({
    where,
    include: { variants: true, set: true },
    orderBy: { cardCode: 'asc' },
  })) as CardWithVariants[];

  const variantIds = cards.flatMap((c) => c.variants.map((v) => v.variantId));
  const prices = await currentPriceMap(prisma, variantIds);
  return cards.map((c) => toCardDto(c, prices));
}

/**
 * Card ids with any catalog or price change strictly after `since`.
 * Covers card edits, variant edits, and new price captures.
 */
export async function changedCardIds(
  prisma: PrismaClient,
  since: Date,
): Promise<string[]> {
  const [cards, variants, pricedVariantIds] = await Promise.all([
    prisma.card.findMany({ where: { updatedAt: { gt: since } }, select: { id: true } }),
    prisma.cardVariant.findMany({
      where: { updatedAt: { gt: since } },
      select: { cardId: true },
    }),
    prisma.price.findMany({
      where: { capturedAt: { gt: since } },
      select: { variantId: true },
      distinct: ['variantId'],
    }),
  ]);

  const ids = new Set<string>();
  for (const c of cards) ids.add(c.id);
  for (const v of variants) ids.add(v.cardId);

  if (pricedVariantIds.length > 0) {
    for (const batch of chunk(pricedVariantIds.map((p) => p.variantId), 1000)) {
      const owners = await prisma.cardVariant.findMany({
        where: { variantId: { in: batch } },
        select: { cardId: true },
      });
      for (const o of owners) ids.add(o.cardId);
    }
  }
  return [...ids];
}
