import { randomBytes } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import type {
  PublicCollectionResponse,
  ShareStatus,
} from '@op-scanner/shared';
import { currentPriceMap } from '../lib/catalog.js';

function newSlug(): string {
  return randomBytes(12).toString('base64url'); // ~16 url-safe chars
}

export default async function shareRoutes(app: FastifyInstance): Promise<void> {
  // --- GET /share (auth): current share status ---
  app.get(
    '/share',
    {
      onRequest: [app.authenticate],
      schema: { tags: ['share'], summary: 'Get share status', security: [{ bearerAuth: [] }] },
    },
    async (request): Promise<ShareStatus> => {
      const user = await app.prisma.user.findUnique({
        where: { id: request.user.sub },
        select: { shareSlug: true },
      });
      return { slug: user?.shareSlug ?? null };
    },
  );

  // --- POST /share (auth): enable sharing (idempotent) ---
  app.post(
    '/share',
    {
      onRequest: [app.authenticate],
      schema: { tags: ['share'], summary: 'Enable public sharing', security: [{ bearerAuth: [] }] },
    },
    async (request): Promise<ShareStatus> => {
      const userId = request.user.sub;
      const existing = await app.prisma.user.findUnique({
        where: { id: userId },
        select: { shareSlug: true },
      });
      if (existing?.shareSlug) return { slug: existing.shareSlug };
      const updated = await app.prisma.user.update({
        where: { id: userId },
        data: { shareSlug: newSlug() },
        select: { shareSlug: true },
      });
      return { slug: updated.shareSlug };
    },
  );

  // --- DELETE /share (auth): disable sharing ---
  app.delete(
    '/share',
    {
      onRequest: [app.authenticate],
      schema: { tags: ['share'], summary: 'Disable public sharing', security: [{ bearerAuth: [] }] },
    },
    async (request, reply) => {
      await app.prisma.user.update({
        where: { id: request.user.sub },
        data: { shareSlug: null },
      });
      return reply.code(204).send();
    },
  );

  // --- GET /share/:slug (PUBLIC): read-only collection ---
  app.get<{ Params: { slug: string } }>(
    '/share/:slug',
    {
      schema: {
        tags: ['share'],
        summary: 'Public read-only view of a shared collection',
      },
    },
    async (request, reply) => {
      const owner = await app.prisma.user.findUnique({
        where: { shareSlug: request.params.slug },
        select: { id: true },
      });
      if (!owner) {
        return reply.code(404).send({ error: 'not found' });
      }

      const items = await app.prisma.collectionItem.findMany({
        where: { userId: owner.id, deletedAt: null },
        include: {
          variant: { include: { card: { include: { set: true } } } },
          tags: { include: { tag: true } },
        },
        orderBy: { addedAt: 'desc' },
      });

      const prices = await currentPriceMap(app.prisma, items.map((i) => i.variantId));

      let copies = 0;
      let value = 0;
      const mapped = items.map((i) => {
        const v = i.variant;
        const c = v.card;
        const price = prices.get(i.variantId)?.marketPrice ?? null;
        copies += i.quantity;
        value += (price ?? 0) * i.quantity;
        return {
          variantId: i.variantId,
          cardCode: c.cardCode,
          name: c.name,
          setCode: c.set.code,
          thumbUrl: `/img/variants/${encodeURIComponent(i.variantId)}/thumb`,
          rarity: v.rarity,
          isAltArt: v.isAltArt,
          variantLabel: v.variantLabel,
          quantity: i.quantity,
          condition: i.condition as PublicCollectionResponse['items'][number]['condition'],
          marketPrice: price,
          tags: i.tags.map((t) => t.tag).filter((t) => t.deletedAt === null).map((t) => t.name),
        };
      });

      return {
        summary: { entries: items.length, copies, value },
        items: mapped,
      };
    },
  );
}
