import type { PrismaClient } from '@prisma/client';
import type { CollectionItemDto, CollectionMutation } from '@op-scanner/shared';

export interface ApplyResult {
  applied: number;
  skipped: number; // LWW: server copy was newer/equal (incl. idempotent replays)
  rejected: string[]; // clientUuids that couldn't be applied (bad data / not owned / unknown variant)
}

export function toCollectionItemDto(item: {
  clientUuid: string;
  variantId: string;
  quantity: number;
  condition: string;
  isFoil: boolean;
  notes: string | null;
  updatedAt: Date;
  deletedAt: Date | null;
  addedAt: Date;
}): CollectionItemDto {
  return {
    clientUuid: item.clientUuid,
    variantId: item.variantId,
    quantity: item.quantity,
    condition: item.condition as CollectionItemDto['condition'],
    isFoil: item.isFoil,
    notes: item.notes,
    updatedAt: item.updatedAt.toISOString(),
    deletedAt: item.deletedAt ? item.deletedAt.toISOString() : null,
    addedAt: item.addedAt.toISOString(),
  };
}

/**
 * Apply a batch of client mutations with last-write-wins by `updatedAt`.
 * - Idempotent: replaying the same batch is a no-op (server copy has equal
 *   updatedAt -> skipped).
 * - Honors soft deletes (tombstones via deletedAt).
 * - Ignores items owned by another user or referencing an unknown variant.
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
        rejected.push(m.clientUuid); // not your item
        continue;
      }
      if (existing.updatedAt >= updatedAt) {
        skipped++; // server copy is newer or identical (LWW / idempotent replay)
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
      applied++;
      continue;
    }

    // New item — ensure the variant exists (FK safety).
    const variant = await prisma.cardVariant.findUnique({
      where: { variantId: m.variantId },
      select: { variantId: true },
    });
    if (!variant) {
      rejected.push(m.clientUuid);
      continue;
    }
    await prisma.collectionItem.create({
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
    applied++;
  }

  return { applied, skipped, rejected };
}
