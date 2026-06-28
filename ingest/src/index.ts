/**
 * Card-data ingestion entrypoint.
 *
 *   npm run ingest            # live: apitcg (metadata/images) + optcgapi (prices)
 *   npm run ingest fixture    # offline sample data (no network/keys)
 *
 * Env: APITCG_API_KEY (required for the live profile), DATABASE_URL.
 * Phase 3 adds pHash precompute over the ingested variant images.
 */
import 'dotenv/config';
import { prisma } from './db.js';
import { runIngest, type IngestConfig } from './pipeline/run.js';
import { ApiTcgSource } from './sources/apitcg.js';
import { OptcgApiSource } from './sources/optcgapi.js';
import { FixtureSource } from './sources/fixture.js';
import { precomputePhashes } from './phash/precompute.js';

function buildConfig(profile: string): IngestConfig {
  switch (profile) {
    case 'fixture': {
      const source = new FixtureSource();
      return { metadata: source, prices: source };
    }
    case 'live':
    case undefined:
    case '': {
      const apiKey = process.env.APITCG_API_KEY;
      if (!apiKey) {
        throw new Error(
          'APITCG_API_KEY is required for the live profile. Set it in ingest/.env (or run `npm run ingest fixture`).',
        );
      }
      return {
        metadata: new ApiTcgSource({ apiKey }),
        prices: new OptcgApiSource(),
      };
    }
    default:
      throw new Error(`Unknown ingest profile "${profile}" (use "live" or "fixture")`);
  }
}

async function main(): Promise<void> {
  const profile = process.argv[2] ?? 'live';

  // `ingest phash [setCode]` — precompute recognition hashes (see /shared/HASHING.md).
  if (profile === 'phash') {
    const setCode = process.argv[3];
    const limit = process.env.PHASH_LIMIT ? Number(process.env.PHASH_LIMIT) : undefined;
    const force = process.env.PHASH_FORCE === '1';
    const r = await precomputePhashes({ setCode, limit, force });
    console.log(`[phash] done ${r.done}, failed ${r.failed}, total ${r.total}`);
    return;
  }

  const config = buildConfig(profile);
  await runIngest(config);
}

main()
  .catch((err) => {
    console.error('[ingest] failed:', err);
    process.exitCode = 1;
  })
  .finally(() => {
    void prisma.$disconnect();
  });
