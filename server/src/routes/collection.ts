import type { FastifyInstance } from 'fastify';
import type { Prisma } from '@prisma/client';
import type {
  CollectionEntryDto,
  CollectionSyncRequest,
  CollectionSyncResponse,
} from '@op-scanner/shared';
import { currentPriceMap } from '../lib/catalog.js';
import { applyMutations, toCollectionItemDto } from '../lib/collectionSync.js';

const mutationSchema = {
  type: 'object',
  required: ['clientUuid', 'variantId', 'quantity', 'condition', 'isFoil', 'updatedAt', 'deleted'],
  properties: {
    clientUuid: { type: 'string' },
    variantId: { type: 'string' },
    quantity: { type: 'integer', minimum: 0 },
    condition: { type: 'string', enum: ['NM', 'LP', 'MP', 'HP', 'DMG'] },
    isFoil: { type: 'boolean' },
    notes: { type: ['string', 'null'] },
    updatedAt: { type: 'string' },
    deleted: { type: 'boolean' },
  },
} as const;

export default async function collectionRoutes(app: FastifyInstance): Promise<void> {
  // --- GET /collection (rich, joined with catalog + price) ---
  app.get<{
    Querystring: {
      q?: string;
      set?: string;
      color?: string;
      type?: string;
      rarity?: string;
      condition?: string;
      sort?: string;
    };
  }>(
    '/collection',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['collection'],
        summary: 'List the authenticated user\'s collection',
        security: [{ bearerAuth: [] }],
        querystring: {
          type: 'object',
          properties: {
            q: { type: 'string' },
            set: { type: 'string' },
            color: { type: 'string' },
            type: { type: 'string' },
            rarity: { type: 'string' },
            condition: { type: 'string', enum: ['NM', 'LP', 'MP', 'HP', 'DMG'] },
            sort: { type: 'string', enum: ['added', 'name', 'priceDesc', 'priceAsc', 'quantity'], default: 'added' },
          },
        },
      },
    },
    async (request): Promise<CollectionEntryDto[]> => {
      const userId = request.user.sub;
      const { q, set, color, type, rarity, condition, sort = 'added' } = request.query;

      const where: Prisma.CollectionItemWhereInput = {
        userId,
        deletedAt: null,
        ...(condition ? { condition: condition as Prisma.CollectionItemWhereInput['condition'] } : {}),
        variant: {
          ...(rarity ? { rarity } : {}),
          card: {
            ...(set ? { set: { code: set } } : {}),
            ...(type ? { type: type as Prisma.CardWhereInput['type'] } : {}),
            ...(color ? { colors: { has: color } } : {}),
            ...(q
              ? {
                  OR: [
                    { name: { contains: q, mode: 'insensitive' } },
                    { cardCode: { contains: q, mode: 'insensitive' } },
                  ],
                }
              : {}),
          },
        },
      };

      const items = await app.prisma.collectionItem.findMany({
        where,
        include: { variant: { include: { card: { include: { set: true } } } } },
      });

      const prices = await currentPriceMap(
        app.prisma,
        items.map((i) => i.variantId),
      );

      const entries: CollectionEntryDto[] = items.map((i) => {
        const v = i.variant;
        const c = v.card;
        return {
          ...toCollectionItemDto(i),
          card: {
            id: c.id,
            name: c.name,
            cardCode: c.cardCode,
            setCode: c.set.code,
            colors: c.colors,
            type: c.type,
          },
          variant: {
            rarity: v.rarity,
            isAltArt: v.isAltArt,
            variantLabel: v.variantLabel,
            thumbUrl: `/img/variants/${encodeURIComponent(v.variantId)}/thumb`,
          },
          currentPrice: prices.get(i.variantId) ?? null,
        };
      });

      const priceOf = (e: CollectionEntryDto) => e.currentPrice?.marketPrice ?? -1;
      switch (sort) {
        case 'name':
          entries.sort((a, b) => a.card.name.localeCompare(b.card.name));
          break;
        case 'priceDesc':
          entries.sort((a, b) => priceOf(b) - priceOf(a));
          break;
        case 'priceAsc':
          entries.sort((a, b) => priceOf(a) - priceOf(b));
          break;
        case 'quantity':
          entries.sort((a, b) => b.quantity - a.quantity);
          break;
        default:
          entries.sort((a, b) => b.addedAt.localeCompare(a.addedAt));
      }
      return entries;
    },
  );

  // --- POST /collection/sync (offline mutation batch -> authoritative state) ---
  app.post<{ Body: CollectionSyncRequest }>(
    '/collection/sync',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['collection'],
        summary: 'Offline sync: apply mutations (LWW), return authoritative items',
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['mutations'],
          properties: {
            since: { type: 'string' },
            mutations: { type: 'array', items: mutationSchema },
          },
        },
      },
    },
    async (request): Promise<CollectionSyncResponse> => {
      const userId = request.user.sub;
      const serverTime = new Date().toISOString();

      await applyMutations(app.prisma, userId, request.body.mutations ?? []);

      // Authoritative items changed since `since` (incl. tombstones so deletes propagate).
      let since: Date | null = null;
      if (request.body.since) {
        const d = new Date(request.body.since);
        if (!Number.isNaN(d.getTime())) since = d;
      }
      const items = await app.prisma.collectionItem.findMany({
        where: { userId, ...(since ? { updatedAt: { gt: since } } : {}) },
        orderBy: { updatedAt: 'asc' },
      });

      return { serverTime, items: items.map(toCollectionItemDto) };
    },
  );
}
