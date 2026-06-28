import { describe, expect, it } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import type { CollectionMutation } from '@op-scanner/shared';
import { applyMutations } from './collectionSync.js';

/** Minimal in-memory fake of the Prisma surface applyMutations touches. */
function fakePrisma(knownVariants: string[]) {
  const store = new Map<string, Record<string, unknown>>();
  const known = new Set(knownVariants);
  const prisma = {
    collectionItem: {
      findUnique: async ({ where }: { where: { clientUuid: string } }) =>
        store.get(where.clientUuid) ?? null,
      update: async ({ where, data }: { where: { clientUuid: string }; data: Record<string, unknown> }) => {
        const next = { ...store.get(where.clientUuid), ...data };
        store.set(where.clientUuid, next);
        return next;
      },
      create: async ({ data }: { data: Record<string, unknown> }) => {
        store.set(data['clientUuid'] as string, data);
        return data;
      },
    },
    cardVariant: {
      findUnique: async ({ where }: { where: { variantId: string } }) =>
        known.has(where.variantId) ? { variantId: where.variantId } : null,
    },
  };
  return { prisma: prisma as unknown as PrismaClient, store };
}

function mutation(over: Partial<CollectionMutation>): CollectionMutation {
  return {
    clientUuid: 'u1',
    variantId: 'OP01-016',
    quantity: 1,
    condition: 'NM',
    isFoil: false,
    notes: null,
    updatedAt: '2026-06-28T10:00:00.000Z',
    deleted: false,
    ...over,
  };
}

describe('applyMutations (LWW conflict resolver)', () => {
  it('creates a new item', async () => {
    const { prisma, store } = fakePrisma(['OP01-016']);
    const r = await applyMutations(prisma, 'user1', [mutation({})]);
    expect(r).toMatchObject({ applied: 1, skipped: 0, rejected: [] });
    expect(store.get('u1')).toMatchObject({ userId: 'user1', quantity: 1 });
  });

  it('is idempotent: replaying the same batch is a no-op', async () => {
    const { prisma } = fakePrisma(['OP01-016']);
    const batch = [mutation({})];
    await applyMutations(prisma, 'user1', batch);
    const r2 = await applyMutations(prisma, 'user1', batch);
    expect(r2).toMatchObject({ applied: 0, skipped: 1 });
  });

  it('last-write-wins: newer updatedAt applies, older is skipped', async () => {
    const { prisma, store } = fakePrisma(['OP01-016']);
    await applyMutations(prisma, 'user1', [mutation({ quantity: 1 })]);

    const newer = mutation({ quantity: 5, updatedAt: '2026-06-28T11:00:00.000Z' });
    expect(await applyMutations(prisma, 'user1', [newer])).toMatchObject({ applied: 1 });
    expect(store.get('u1')).toMatchObject({ quantity: 5 });

    const older = mutation({ quantity: 99, updatedAt: '2026-06-28T09:00:00.000Z' });
    expect(await applyMutations(prisma, 'user1', [older])).toMatchObject({ skipped: 1 });
    expect(store.get('u1')).toMatchObject({ quantity: 5 }); // unchanged
  });

  it('honors soft deletes (tombstone via deletedAt)', async () => {
    const { prisma, store } = fakePrisma(['OP01-016']);
    await applyMutations(prisma, 'user1', [mutation({})]);
    await applyMutations(prisma, 'user1', [
      mutation({ deleted: true, updatedAt: '2026-06-28T12:00:00.000Z' }),
    ]);
    expect(store.get('u1')!['deletedAt']).toBeInstanceOf(Date);
  });

  it('rejects unknown variants', async () => {
    const { prisma } = fakePrisma([]); // no known variants
    const r = await applyMutations(prisma, 'user1', [mutation({ variantId: 'NOPE-001' })]);
    expect(r.rejected).toEqual(['u1']);
    expect(r.applied).toBe(0);
  });

  it("refuses to mutate another user's item", async () => {
    const { prisma } = fakePrisma(['OP01-016']);
    await applyMutations(prisma, 'user1', [mutation({})]);
    const r = await applyMutations(prisma, 'attacker', [
      mutation({ quantity: 999, updatedAt: '2026-06-28T13:00:00.000Z' }),
    ]);
    expect(r.rejected).toEqual(['u1']);
  });
});
