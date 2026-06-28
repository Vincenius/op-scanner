import type { PrismaClient } from '@prisma/client';
import type {
  CollectionItemDto,
  CollectionMutation,
  TagMutation,
} from '@op-scanner/shared';

export interface ApplyResult {
  applied: number;
  skipped: number; // LWW: server copy was newer/equal (incl. idempotent replays)
  rejected: string[]; // clientUuids that couldn't be applied (bad data / not owned / unknown variant)
}

export function toCollectionItemDto(
  item: {
    clientUuid: string;
    variantId: string;
    quantity: number;
    condition: string;
    isFoil: boolean;
    notes: string | null;
    updatedAt: Date;
    deletedAt: Date | null;
    addedAt: Date;
  },
  tagClientUuids: string[],
): CollectionItemDto {
  return {
    clientUuid: item.clientUuid,
    variantId: item.variantId,
    quantity: item.quantity,
    condition: item.condition as CollectionItemDto['condition'],
    isFoil: item.isFoil,
    notes: item.notes,
    tagClientUuids,
    updatedAt: item.updatedAt.toISOString(),
    deletedAt: item.deletedAt ? item.deletedAt.toISOString() : null,
    addedAt: item.addedAt.toISOString(),
  };
}

/** Apply tag entities with last-write-wins by `updatedAt` (idempotent, soft-delete). */
export async function applyTags(
  prisma: PrismaClient,
  userId: string,
  tags: TagMutation[],
): Promise<ApplyResult> {
  let applied = 0;
  let skipped = 0;
  const rejected: string[] = [];

  for (const t of tags) {
    const updatedAt = new Date(t.updatedAt);
    if (Number.isNaN(updatedAt.getTime()) || !t.clientUuid || !t.name) {
      rejected.push(t.clientUuid);
      continue;
    }
    const existing = await prisma.tag.findUnique({ where: { clientUuid: t.clientUuid } });
    if (existing) {
      if (existing.userId !== userId) {
        rejected.push(t.clientUuid);
        continue;
      }
      if (existing.updatedAt >= updatedAt) {
        skipped++;
        continue;
      }
      await prisma.tag.update({
        where: { clientUuid: t.clientUuid },
        data: { name: t.name, color: t.color, updatedAt, deletedAt: t.deleted ? updatedAt : null },
      });
      applied++;
    } else {
      await prisma.tag.create({
        data: {
          userId,
          clientUuid: t.clientUuid,
          name: t.name,
          color: t.color,
          createdAt: updatedAt,
          updatedAt,
          deletedAt: t.deleted ? updatedAt : null,
        },
      });
      applied++;
    }
  }
  return { applied, skipped, rejected };
}

/** Set a collection entry's tag links to exactly `tagClientUuids` (owned by user). */
async function setItemTags(
  prisma: PrismaClient,
  userId: string,
  collectionItemId: string,
  tagClientUuids: string[],
): Promise<void> {
  const tagIds = tagClientUuids.length
    ? (
        await prisma.tag.findMany({
          where: { userId, clientUuid: { in: tagClientUuids } },
          select: { id: true },
        })
      ).map((t) => t.id)
    : [];

  if (tagIds.length === 0) {
    await prisma.collectionItemTag.deleteMany({ where: { collectionItemId } });
    return;
  }
  // Atomic replace so a concurrent sync can't observe a half-applied tag set.
  await prisma.$transaction([
    prisma.collectionItemTag.deleteMany({
      where: { collectionItemId, tagId: { notIn: tagIds } },
    }),
    prisma.collectionItemTag.createMany({
      data: tagIds.map((tagId) => ({ collectionItemId, tagId })),
      skipDuplicates: true,
    }),
  ]);
}

/**
 * Apply a batch of client mutations with last-write-wins by `updatedAt`.
 * - Idempotent: replaying the same batch is a no-op.
 * - Honors soft deletes (tombstones via deletedAt).
 * - Replaces each entry's tag links with the mutation's tagClientUuids.
 * - Ignores items owned by another user or referencing an unknown variant.
 * NOTE: call applyTags() first so referenced tags exist.
 */
export async function applyMutations(
  prisma: PrismaClient,
  userId: string,
  mutations: CollectionMutation[],
): Promise<ApplyResult> {
  let applied = 0;
  let skipped = 0;
  const rejected: string[] = [];

  for (const m of mutations) {
    const updatedAt = new Date(m.updatedAt);
    if (Number.isNaN(updatedAt.getTime()) || !m.clientUuid || !m.variantId) {
      rejected.push(m.clientUuid);
      continue;
    }

    const existing = await prisma.collectionItem.findUnique({
      where: { clientUuid: m.clientUuid },
    });

    if (existing) {
      if (existing.userId !== userId) {
        rejected.push(m.clientUuid);
        continue;
      }
      if (existing.updatedAt >= updatedAt) {
        skipped++;
        continue;
      }
      await prisma.collectionItem.update({
        where: { clientUuid: m.clientUuid },
        data: {
          variantId: m.variantId,
          quantity: m.quantity,
          condition: m.condition,
          isFoil: m.isFoil,
          notes: m.notes ?? null,
          updatedAt,
          deletedAt: m.deleted ? updatedAt : null,
        },
      });
      await setItemTags(prisma, userId, existing.id, m.tagClientUuids ?? []);
      applied++;
      continue;
    }

    const variant = await prisma.cardVariant.findUnique({
      where: { variantId: m.variantId },
      select: { variantId: true },
    });
    if (!variant) {
      rejected.push(m.clientUuid);
      continue;
    }
    const created = await prisma.collectionItem.create({
      data: {
        userId,
        clientUuid: m.clientUuid,
        variantId: m.variantId,
        quantity: m.quantity,
        condition: m.condition,
        isFoil: m.isFoil,
        notes: m.notes ?? null,
        addedAt: updatedAt,
        updatedAt,
        deletedAt: m.deleted ? updatedAt : null,
      },
    });
    await setItemTags(prisma, userId, created.id, m.tagClientUuids ?? []);
    applied++;
  }

  return { applied, skipped, rejected };
}
