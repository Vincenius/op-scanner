import type { FastifyInstance } from 'fastify';
import type { Prisma } from '@prisma/client';
import type {
  CollectionEntryDto,
  CollectionSyncRequest,
  CollectionSyncResponse,
  TagDto,
} from '@op-scanner/shared';
import { currentPriceMap } from '../lib/catalog.js';
import { applyMutations, applyTags, toCollectionItemDto } from '../lib/collectionSync.js';

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
    tagClientUuids: { type: 'array', items: { type: 'string' } },
    updatedAt: { type: 'string' },
    deleted: { type: 'boolean' },
  },
} as const;

const tagSchema = {
  type: 'object',
  required: ['clientUuid', 'name', 'updatedAt', 'deleted'],
  properties: {
    clientUuid: { type: 'string' },
    name: { type: 'string' },
    color: { type: ['string', 'null'] },
    updatedAt: { type: 'string' },
    deleted: { type: 'boolean' },
  },
} as const;

function toTagDto(t: { clientUuid: string; name: string; color: string | null; updatedAt: Date; deletedAt: Date | null }): TagDto {
  return {
    clientUuid: t.clientUuid,
    name: t.name,
    color: t.color,
    updatedAt: t.updatedAt.toISOString(),
    deletedAt: t.deletedAt ? t.deletedAt.toISOString() : null,
  };
}

export default async function collectionRoutes(app: FastifyInstance): Promise<void> {
  // --- GET /collection (rich, joined with catalog + price + tags) ---
  app.get<{
    Querystring: {
      q?: string;
      set?: string;
      color?: string;
      type?: string;
      rarity?: string;
      condition?: string;
      tag?: string; // tag clientUuid
      sort?: string;
    };
  }>(
    '/collection',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['collection'],
        summary: "List the authenticated user's collection",
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
            tag: { type: 'string' },
            sort: { type: 'string', enum: ['added', 'name', 'priceDesc', 'priceAsc', 'quantity'], default: 'added' },
          },
        },
      },
    },
    async (request): Promise<CollectionEntryDto[]> => {
      const userId = request.user.sub;
      const { q, set, color, type, rarity, condition, tag, sort = 'added' } = request.query;

      const where: Prisma.CollectionItemWhereInput = {
        userId,
        deletedAt: null,
        ...(condition ? { condition: condition as Prisma.CollectionItemWhereInput['condition'] } : {}),
        ...(tag ? { tags: { some: { tag: { clientUuid: tag, deletedAt: null } } } } : {}),
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
        include: {
          variant: { include: { card: { include: { set: true } } } },
          tags: { include: { tag: true } },
        },
      });

      const prices = await currentPriceMap(app.prisma, items.map((i) => i.variantId));

      const entries: CollectionEntryDto[] = items.map((i) => {
        const v = i.variant;
        const c = v.card;
        const liveTags = i.tags.map((t) => t.tag).filter((t) => t.deletedAt === null);
        return {
          ...toCollectionItemDto(i, liveTags.map((t) => t.clientUuid)),
          card: { id: c.id, name: c.name, cardCode: c.cardCode, setCode: c.set.code, colors: c.colors, type: c.type },
          variant: { rarity: v.rarity, isAltArt: v.isAltArt, variantLabel: v.variantLabel, thumbUrl: `/img/variants/${encodeURIComponent(v.variantId)}/thumb` },
          currentPrice: prices.get(i.variantId) ?? null,
          tags: liveTags.map((t) => ({ clientUuid: t.clientUuid, name: t.name, color: t.color })),
        };
      });

      const priceOf = (e: CollectionEntryDto) => e.currentPrice?.marketPrice ?? -1;
      switch (sort) {
        case 'name': entries.sort((a, b) => a.card.name.localeCompare(b.card.name)); break;
        case 'priceDesc': entries.sort((a, b) => priceOf(b) - priceOf(a)); break;
        case 'priceAsc': entries.sort((a, b) => priceOf(a) - priceOf(b)); break;
        case 'quantity': entries.sort((a, b) => b.quantity - a.quantity); break;
        default: entries.sort((a, b) => b.addedAt.localeCompare(a.addedAt));
      }
      return entries;
    },
  );

  // --- POST /collection/sync (tags + collection mutations -> authoritative state) ---
  app.post<{ Body: CollectionSyncRequest }>(
    '/collection/sync',
    {
      onRequest: [app.authenticate],
      schema: {
        tags: ['collection'],
        summary: 'Offline sync: apply tag + collection mutations (LWW), return authoritative state',
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['mutations'],
          properties: {
            since: { type: 'string' },
            tags: { type: 'array', items: tagSchema },
            mutations: { type: 'array', items: mutationSchema },
          },
        },
      },
    },
    async (request): Promise<CollectionSyncResponse> => {
      const userId = request.user.sub;
      const serverTime = new Date().toISOString();

      // Tags first so item mutations can reference them.
      await applyTags(app.prisma, userId, request.body.tags ?? []);
      await applyMutations(app.prisma, userId, request.body.mutations ?? []);

      let since: Date | null = null;
      if (request.body.since) {
        const d = new Date(request.body.since);
        if (!Number.isNaN(d.getTime())) since = d;
      }

      const [tags, items] = await Promise.all([
        app.prisma.tag.findMany({
          where: { userId, ...(since ? { updatedAt: { gt: since } } : {}) },
          orderBy: { updatedAt: 'asc' },
        }),
        app.prisma.collectionItem.findMany({
          where: { userId, ...(since ? { updatedAt: { gt: since } } : {}) },
          include: { tags: { include: { tag: { select: { clientUuid: true } } } } },
          orderBy: { updatedAt: 'asc' },
        }),
      ]);

      return {
        serverTime,
        tags: tags.map(toTagDto),
        items: items.map((i) => toCollectionItemDto(i, i.tags.map((t) => t.tag.clientUuid))),
      };
    },
  );
}
