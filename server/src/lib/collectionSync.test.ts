import { describe, expect, it } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import type { CollectionMutation, TagMutation } from '@op-scanner/shared';
import { applyMutations, applyTags } from './collectionSync.js';

/** In-memory fake of the Prisma surface applyMutations/applyTags touch. */
function fakePrisma(knownVariants: string[]) {
  const items = new Map<string, Record<string, unknown>>(); // by clientUuid
  const tags = new Map<string, Record<string, unknown>>(); // by clientUuid
  const links = new Set<string>(); // `${itemId}|${tagId}`
  const known = new Set(knownVariants);

  const prisma = {
    // Ops are eagerly-executed in this fake, so the array form just awaits them.
    $transaction: async (ops: Promise<unknown>[]) => Promise.all(ops),
    collectionItem: {
      findUnique: async ({ where }: { where: { clientUuid: string } }) => items.get(where.clientUuid) ?? null,
      update: async ({ where, data }: { where: { clientUuid: string }; data: Record<string, unknown> }) => {
        const next = { ...items.get(where.clientUuid), ...data };
        items.set(where.clientUuid, next);
        return next;
      },
      create: async ({ data }: { data: Record<string, unknown> }) => {
        const row = { ...data, id: data['clientUuid'] };
        items.set(data['clientUuid'] as string, row);
        return row;
      },
    },
    cardVariant: {
      findUnique: async ({ where }: { where: { variantId: string } }) =>
        known.has(where.variantId) ? { variantId: where.variantId } : null,
    },
    tag: {
      findUnique: async ({ where }: { where: { clientUuid: string } }) => tags.get(where.clientUuid) ?? null,
      create: async ({ data }: { data: Record<string, unknown> }) => {
        const row = { ...data, id: data['clientUuid'] };
        tags.set(data['clientUuid'] as string, row);
        return row;
      },
      update: async ({ where, data }: { where: { clientUuid: string }; data: Record<string, unknown> }) => {
        const next = { ...tags.get(where.clientUuid), ...data };
        tags.set(where.clientUuid, next);
        return next;
      },
      findMany: async ({ where }: { where: { userId: string; clientUuid: { in: string[] } } }) =>
        [...tags.values()]
          .filter((t) => t['userId'] === where.userId && where.clientUuid.in.includes(t['clientUuid'] as string))
          .map((t) => ({ id: t['id'] })),
    },
    collectionItemTag: {
      deleteMany: async ({ where }: { where: { collectionItemId: string; tagId?: { notIn: string[] } } }) => {
        for (const key of [...links]) {
          const [itemId, tagId] = key.split('|');
          if (itemId !== where.collectionItemId) continue;
          if (where.tagId && where.tagId.notIn.includes(tagId!)) continue;
          links.delete(key);
        }
        return { count: 0 };
      },
      createMany: async ({ data }: { data: { collectionItemId: string; tagId: string }[] }) => {
        for (const d of data) links.add(`${d.collectionItemId}|${d.tagId}`);
        return { count: data.length };
      },
    },
  };
  return { prisma: prisma as unknown as PrismaClient, items, tags, links };
}

function mutation(over: Partial<CollectionMutation>): CollectionMutation {
  return {
    clientUuid: 'u1',
    variantId: 'OP01-016',
    quantity: 1,
    condition: 'NM',
    isFoil: false,
    notes: null,
    tagClientUuids: [],
    updatedAt: '2026-06-28T10:00:00.000Z',
    deleted: false,
    ...over,
  };
}

function tag(over: Partial<TagMutation>): TagMutation {
  return {
    clientUuid: 't1',
    name: 'Green Deck Box',
    color: null,
    updatedAt: '2026-06-28T10:00:00.000Z',
    deleted: false,
    ...over,
  };
}

describe('applyMutations (LWW conflict resolver)', () => {
  it('creates a new item', async () => {
    const { prisma, items } = fakePrisma(['OP01-016']);
    const r = await applyMutations(prisma, 'user1', [mutation({})]);
    expect(r).toMatchObject({ applied: 1, skipped: 0, rejected: [] });
    expect(items.get('u1')).toMatchObject({ userId: 'user1', quantity: 1 });
  });

  it('is idempotent: replaying the same batch is a no-op', async () => {
    const { prisma } = fakePrisma(['OP01-016']);
    const batch = [mutation({})];
    await applyMutations(prisma, 'user1', batch);
    expect(await applyMutations(prisma, 'user1', batch)).toMatchObject({ applied: 0, skipped: 1 });
  });

  it('last-write-wins: newer applies, older is skipped', async () => {
    const { prisma, items } = fakePrisma(['OP01-016']);
    await applyMutations(prisma, 'user1', [mutation({ quantity: 1 })]);
    expect(await applyMutations(prisma, 'user1', [mutation({ quantity: 5, updatedAt: '2026-06-28T11:00:00.000Z' })])).toMatchObject({ applied: 1 });
    expect(items.get('u1')).toMatchObject({ quantity: 5 });
    expect(await applyMutations(prisma, 'user1', [mutation({ quantity: 99, updatedAt: '2026-06-28T09:00:00.000Z' })])).toMatchObject({ skipped: 1 });
    expect(items.get('u1')).toMatchObject({ quantity: 5 });
  });

  it('honors soft deletes', async () => {
    const { prisma, items } = fakePrisma(['OP01-016']);
    await applyMutations(prisma, 'user1', [mutation({})]);
    await applyMutations(prisma, 'user1', [mutation({ deleted: true, updatedAt: '2026-06-28T12:00:00.000Z' })]);
    expect(items.get('u1')!['deletedAt']).toBeInstanceOf(Date);
  });

  it('rejects unknown variants', async () => {
    const { prisma } = fakePrisma([]);
    const r = await applyMutations(prisma, 'user1', [mutation({ variantId: 'NOPE-001' })]);
    expect(r.rejected).toEqual(['u1']);
  });

  it("refuses to mutate another user's item", async () => {
    const { prisma } = fakePrisma(['OP01-016']);
    await applyMutations(prisma, 'user1', [mutation({})]);
    expect(await applyMutations(prisma, 'attacker', [mutation({ quantity: 999, updatedAt: '2026-06-28T13:00:00.000Z' })])).toMatchObject({ rejected: ['u1'] });
  });
});

describe('applyTags + tag assignment', () => {
  it('creates a tag, then assigns it to an item (link created)', async () => {
    const { prisma, tags, links } = fakePrisma(['OP01-016']);
    await applyTags(prisma, 'user1', [tag({})]);
    expect(tags.get('t1')).toMatchObject({ name: 'Green Deck Box', userId: 'user1' });

    await applyMutations(prisma, 'user1', [mutation({ tagClientUuids: ['t1'] })]);
    expect(links.has('u1|t1')).toBe(true);
  });

  it('replaces the tag set on update (remove a tag)', async () => {
    const { prisma, links } = fakePrisma(['OP01-016']);
    await applyTags(prisma, 'user1', [tag({ clientUuid: 't1' }), tag({ clientUuid: 't2', name: 'Blue Box' })]);
    await applyMutations(prisma, 'user1', [mutation({ tagClientUuids: ['t1', 't2'] })]);
    expect(links.has('u1|t1') && links.has('u1|t2')).toBe(true);

    // Update with only t2 -> t1 link removed.
    await applyMutations(prisma, 'user1', [mutation({ tagClientUuids: ['t2'], updatedAt: '2026-06-28T11:00:00.000Z' })]);
    expect(links.has('u1|t1')).toBe(false);
    expect(links.has('u1|t2')).toBe(true);
  });

  it('tag LWW: idempotent replay + soft delete', async () => {
    const { prisma, tags } = fakePrisma([]);
    const batch = [tag({})];
    expect(await applyTags(prisma, 'user1', batch)).toMatchObject({ applied: 1 });
    expect(await applyTags(prisma, 'user1', batch)).toMatchObject({ skipped: 1 });
    await applyTags(prisma, 'user1', [tag({ deleted: true, updatedAt: '2026-06-28T12:00:00.000Z' })]);
    expect(tags.get('t1')!['deletedAt']).toBeInstanceOf(Date);
  });
});
