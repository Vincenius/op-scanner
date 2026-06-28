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

/** Validate + rotate a presented refresh token. Returns null if invalid. */
export async function rotateRefreshToken(
  prisma: PrismaClient,
  presented: string,
): Promise<RotatedRefresh | null> {
  const existing = await prisma.refreshToken.findUnique({
    where: { tokenHash: hashToken(presented) },
  });
  if (!existing || existing.revokedAt || existing.expiresAt < new Date()) {
    return null;
  }
  const token = randomBytes(32).toString('hex');
  const expiresAt = refreshExpiry();
  const created = await prisma.refreshToken.create({
    data: { userId: existing.userId, tokenHash: hashToken(token), expiresAt },
  });
  await prisma.refreshToken.update({
    where: { id: existing.id },
    data: { revokedAt: new Date(), replacedBy: created.id },
  });
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
