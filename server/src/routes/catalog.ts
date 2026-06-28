import type { FastifyInstance } from 'fastify';
import type { Prisma } from '@prisma/client';
import type {
  CatalogSyncResponse,
  PagedCards,
  SetDto,
  VariantDto,
} from '@op-scanner/shared';
import {
  changedCardIds,
  currentPriceMap,
  loadCards,
} from '../lib/catalog.js';
import { toSetDto, toVariantDto, type CardWithVariants } from '../lib/mappers.js';

export default async function catalogRoutes(app: FastifyInstance): Promise<void> {
  // --- GET /sets ---
  app.get(
    '/sets',
    { schema: { tags: ['catalog'], summary: 'List all sets' } },
    async (): Promise<SetDto[]> => {
      const sets = await app.prisma.set.findMany({ orderBy: { code: 'asc' } });
      return sets.map(toSetDto);
    },
  );

  // --- GET /cards (filter + paginate) ---
  app.get<{
    Querystring: {
      set?: string;
      color?: string;
      type?: string;
      rarity?: string;
      q?: string;
      page?: number;
      pageSize?: number;
    };
  }>(
    '/cards',
    {
      schema: {
        tags: ['catalog'],
        summary: 'List/filter cards (paginated)',
        querystring: {
          type: 'object',
          properties: {
            set: { type: 'string', description: 'set code, e.g. OP01' },
            color: { type: 'string' },
            type: { type: 'string', enum: ['LEADER', 'CHARACTER', 'EVENT', 'STAGE', 'DON'] },
            rarity: { type: 'string' },
            q: { type: 'string', description: 'name or card-code search' },
            page: { type: 'integer', minimum: 1, default: 1 },
            pageSize: { type: 'integer', minimum: 1, maximum: 200, default: 50 },
          },
        },
      },
    },
    async (request): Promise<PagedCards> => {
      const { set, color, type, rarity, q, page = 1, pageSize = 50 } = request.query;
      const where: Prisma.CardWhereInput = {
        ...(set ? { set: { code: set } } : {}),
        ...(color ? { colors: { has: color } } : {}),
        ...(type ? { type: type as Prisma.CardWhereInput['type'] } : {}),
        ...(rarity ? { variants: { some: { rarity } } } : {}),
        ...(q
          ? {
              OR: [
                { name: { contains: q, mode: 'insensitive' } },
                { cardCode: { contains: q, mode: 'insensitive' } },
              ],
            }
          : {}),
      };

      const total = await app.prisma.card.count({ where });
      const ids = await app.prisma.card.findMany({
        where,
        select: { id: true },
        orderBy: { cardCode: 'asc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
      });
      const data = await loadCards(app.prisma, { id: { in: ids.map((r) => r.id) } });
      return {
        page,
        pageSize,
        total,
        totalPages: Math.ceil(total / pageSize),
        data,
      };
    },
  );

  // --- GET /variants/:variantId (with current price) ---
  app.get<{ Params: { variantId: string } }>(
    '/variants/:variantId',
    { schema: { tags: ['catalog'], summary: 'Variant detail incl. current price' } },
    async (request, reply): Promise<VariantDto | undefined> => {
      const variant = (await app.prisma.cardVariant.findUnique({
        where: { variantId: request.params.variantId },
      })) as CardWithVariants['variants'][number] | null;
      if (!variant) {
        reply.code(404);
        return undefined;
      }
      const prices = await currentPriceMap(app.prisma, [variant.variantId]);
      return toVariantDto(variant, prices.get(variant.variantId) ?? null);
    },
  );

  // --- GET /variants/:variantId/prices?range=1m|3m|6m|1y ---
  app.get<{ Params: { variantId: string }; Querystring: { range?: string } }>(
    '/variants/:variantId/prices',
    {
      schema: {
        tags: ['catalog'],
        summary: 'Price history for a variant',
        querystring: {
          type: 'object',
          properties: {
            range: { type: 'string', enum: ['1m', '3m', '6m', '1y', 'all'], default: '3m' },
          },
        },
      },
    },
    async (request) => {
      const { range = '3m' } = request.query;
      const since = rangeToSince(range);
      const rows = await app.prisma.price.findMany({
        where: {
          variantId: request.params.variantId,
          ...(since ? { capturedAt: { gte: since } } : {}),
        },
        orderBy: { capturedAt: 'asc' },
      });
      return rows.map((p) => ({
        source: p.source,
        currency: p.currency,
        marketPrice: p.marketPrice ? Number(p.marketPrice) : null,
        lowPrice: p.lowPrice ? Number(p.lowPrice) : null,
        capturedAt: p.capturedAt.toISOString(),
      }));
    },
  );

  // --- GET /catalog/sync?since=<ISO> ---
  app.get<{ Querystring: { since?: string } }>(
    '/catalog/sync',
    {
      schema: {
        tags: ['catalog'],
        summary: 'Catalog delta (sets + cards + variants + current prices) for offline mirror',
        querystring: {
          type: 'object',
          properties: {
            since: { type: 'string', description: 'ISO timestamp from a previous sync' },
          },
        },
      },
    },
    async (request, reply): Promise<CatalogSyncResponse | undefined> => {
      const serverTime = new Date().toISOString();
      const sinceRaw = request.query.since;
      let since: Date | null = null;
      if (sinceRaw) {
        const d = new Date(sinceRaw);
        if (Number.isNaN(d.getTime())) {
          reply.code(400);
          return undefined;
        }
        since = d;
      }

      if (!since) {
        // Full snapshot
        const [sets, cards] = await Promise.all([
          app.prisma.set.findMany({ orderBy: { code: 'asc' } }),
          loadCards(app.prisma, {}),
        ]);
        return { serverTime, full: true, sets: sets.map(toSetDto), cards };
      }

      // Delta
      const [sets, ids] = await Promise.all([
        app.prisma.set.findMany({ where: { updatedAt: { gt: since } }, orderBy: { code: 'asc' } }),
        changedCardIds(app.prisma, since),
      ]);
      const cards = ids.length > 0 ? await loadCards(app.prisma, { id: { in: ids } }) : [];
      return { serverTime, full: false, sets: sets.map(toSetDto), cards };
    },
  );
}

function rangeToSince(range: string): Date | null {
  const now = Date.now();
  const day = 24 * 60 * 60 * 1000;
  switch (range) {
    case '1m': return new Date(now - 30 * day);
    case '3m': return new Date(now - 90 * day);
    case '6m': return new Date(now - 180 * day);
    case '1y': return new Date(now - 365 * day);
    default: return null; // 'all'
  }
}
