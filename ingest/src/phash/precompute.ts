import sharp from 'sharp';
import { prisma } from '../db.js';
import { mapLimit } from '../pipeline/concurrency.js';
import { phashFromRgb, type RgbImage } from './hash.js';

/** Decode image bytes to raw RGB (no alpha) for hashing. */
export async function decodeRgb(buf: Buffer): Promise<RgbImage> {
  const { data, info } = await sharp(buf).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  return {
    data: new Uint8Array(data.buffer, data.byteOffset, data.byteLength),
    width: info.width,
    height: info.height,
  };
}

export interface PrecomputeOpts {
  setCode?: string;
  limit?: number;
  force?: boolean; // recompute even if phash already set
}

/**
 * Precompute card_variant.phash from each variant's full-art image, to the
 * /shared/HASHING.md spec. Idempotent; skips variants already hashed unless force.
 */
export async function precomputePhashes(opts: PrecomputeOpts = {}): Promise<{
  done: number;
  failed: number;
  total: number;
}> {
  const variants = await prisma.cardVariant.findMany({
    where: {
      imageFullUrl: { not: null },
      ...(opts.force ? {} : { phash: null }),
      ...(opts.setCode ? { card: { set: { code: opts.setCode } } } : {}),
    },
    select: { variantId: true, imageFullUrl: true },
    take: opts.limit,
    orderBy: { variantId: 'asc' },
  });

  console.log(`[phash] computing for ${variants.length} variants...`);
  let done = 0;
  let failed = 0;
  await mapLimit(variants, 8, async (v) => {
    try {
      const res = await fetch(v.imageFullUrl!, { headers: { 'user-agent': 'op-scanner-ingest' } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const img = await decodeRgb(Buffer.from(await res.arrayBuffer()));
      const phash = phashFromRgb(img);
      await prisma.cardVariant.update({ where: { variantId: v.variantId }, data: { phash } });
      done++;
      if (done % 50 === 0) console.log(`[phash] ${done}/${variants.length}`);
    } catch (err) {
      failed++;
      console.warn(`[phash] failed ${v.variantId}: ${String(err)}`);
    }
  });
  return { done, failed, total: variants.length };
}
