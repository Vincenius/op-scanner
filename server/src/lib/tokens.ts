import { createHmac, randomBytes } from 'node:crypto';
import type { PrismaClient } from '@prisma/client';
import { env } from '../env.js';

/**
 * Refresh tokens are opaque high-entropy random strings. We store only an
 * HMAC-SHA256 of the token (keyed by JWT_REFRESH_SECRET), so a DB leak doesn't
 * expose usable tokens. Rotation: every refresh issues a new token and revokes
 * the old one (with `replacedBy` for an audit trail / reuse detection later).
 */

function hashToken(token: string): string {
  return createHmac('sha256', env.JWT_REFRESH_SECRET).update(token).digest('hex');
}

function refreshExpiry(): Date {
  return new Date(Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000);
}

export interface IssuedRefresh {
  token: string;
  expiresAt: Date;
}

export async function issueRefreshToken(
  prisma: PrismaClient,
  userId: string,
): Promise<IssuedRefresh> {
  const token = randomBytes(32).toString('hex');
  const expiresAt = refreshExpiry();
  await prisma.refreshToken.create({
    data: { userId, tokenHash: hashToken(token), expiresAt },
  });
  return { token, expiresAt };
}

export interface RotatedRefresh extends IssuedRefresh {
  userId: string;
}

/**
 * Validate + rotate a presented refresh token. Returns null if invalid.
 * - Detects reuse: presenting an already-rotated token revokes the whole family
 *   (likely theft), so a stolen token can't run a parallel session.
 * - Rotation is atomic and guards against two concurrent refreshes both minting.
 */
export async function rotateRefreshToken(
  prisma: PrismaClient,
  presented: string,
): Promise<RotatedRefresh | null> {
  const existing = await prisma.refreshToken.findUnique({
    where: { tokenHash: hashToken(presented) },
  });
  if (!existing) return null;

  if (existing.revokedAt) {
    // Reuse of a token that was already rotated -> revoke every active token for
    // this user (breach response).
    if (existing.replacedBy) {
      await prisma.refreshToken.updateMany({
        where: { userId: existing.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
    return null;
  }
  if (existing.expiresAt < new Date()) return null;

  const token = randomBytes(32).toString('hex');
  const expiresAt = refreshExpiry();
  try {
    await prisma.$transaction(async (tx) => {
      // Revoke the old token only if still active — fails the concurrent racer.
      const revoked = await tx.refreshToken.updateMany({
        where: { id: existing.id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      if (revoked.count === 0) throw new Error('already rotated');
      const created = await tx.refreshToken.create({
        data: { userId: existing.userId, tokenHash: hashToken(token), expiresAt },
      });
      await tx.refreshToken.update({
        where: { id: existing.id },
        data: { replacedBy: created.id },
      });
    });
  } catch {
    return null; // lost a concurrent rotation race
  }
  return { userId: existing.userId, token, expiresAt };
}

export async function revokeRefreshToken(
  prisma: PrismaClient,
  presented: string,
): Promise<void> {
  await prisma.refreshToken.updateMany({
    where: { tokenHash: hashToken(presented), revokedAt: null },
    data: { revokedAt: new Date() },
  });
}
