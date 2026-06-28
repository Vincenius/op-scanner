import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import sharp from 'sharp';
import type { FastifyInstance } from 'fastify';
import { env } from '../env.js';

/** Thumbnails are resized to keep bulk-prefetch feasible (upstream art is ~185KB). */
const THUMB_WIDTH = 280;

/**
 * Thumbnail/full-art proxy. The client only ever references `/img/...`, so
 * upstream image hosts stay swappable and we never redistribute a bulk art
 * archive — images are fetched and cached on demand (per the IP constraint).
 */
const SAFE_ID = /^[A-Za-z0-9_-]+$/;

function sniffContentType(buf: Buffer): string {
  if (buf.length >= 8 && buf[0] === 0x89 && buf[1] === 0x50) return 'image/png';
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8) return 'image/jpeg';
  if (buf.length >= 12 && buf.toString('ascii', 0, 4) === 'RIFF') return 'image/webp';
  return 'application/octet-stream';
}

export default async function imageRoutes(app: FastifyInstance): Promise<void> {
  const cacheDir = env.IMAGE_CACHE_DIR;
  await mkdir(cacheDir, { recursive: true });

  app.get<{ Params: { variantId: string; size: string } }>(
    '/img/variants/:variantId/:size',
    {
      schema: {
        tags: ['images'],
        summary: 'Proxied + cached card image (size: thumb|full)',
      },
    },
    async (request, reply) => {
      const { variantId, size } = request.params;
      if (!SAFE_ID.test(variantId) || (size !== 'thumb' && size !== 'full')) {
        return reply.code(400).send({ error: 'bad request' });
      }

      const cachePath = join(cacheDir, `${variantId}_${size}`);
      if (existsSync(cachePath)) {
        const buf = await readFile(cachePath);
        return reply
          .header('Cache-Control', 'public, max-age=604800')
          .type(sniffContentType(buf))
          .send(buf);
      }

      const variant = await app.prisma.cardVariant.findUnique({
        where: { variantId },
        select: { imageThumbUrl: true, imageFullUrl: true },
      });
      const upstream = size === 'thumb' ? variant?.imageThumbUrl : variant?.imageFullUrl;
      if (!upstream) {
        return reply.code(404).send({ error: 'image not found' });
      }

      try {
        const res = await fetch(upstream, { headers: { 'user-agent': 'op-scanner' } });
        if (!res.ok) {
          request.log.warn({ upstream, status: res.status }, 'upstream image fetch failed');
          return reply.code(502).send({ error: 'upstream image error' });
        }
        const original = Buffer.from(await res.arrayBuffer());
        // Resize thumbnails (webp) so prefetching the whole catalog is feasible;
        // serve full art untouched.
        const buf =
          size === 'thumb'
            ? await sharp(original).resize({ width: THUMB_WIDTH, withoutEnlargement: true }).webp({ quality: 80 }).toBuffer()
            : original;
        await writeFile(cachePath, buf);
        return reply
          .header('Cache-Control', 'public, max-age=604800')
          .type(sniffContentType(buf))
          .send(buf);
      } catch (err) {
        request.log.error({ err, upstream }, 'image proxy error');
        return reply.code(502).send({ error: 'upstream image error' });
      }
    },
  );
}
