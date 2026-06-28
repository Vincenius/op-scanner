/**
 * Card-data ingestion entrypoint (Phase 0 stub).
 *
 * Phase 1 wires up the pluggable {@link CardSource} pipeline: fetch sets /
 * cards / variants / prices from an upstream source, upsert them into Postgres
 * (one `card_variant` row per printing, including alt-arts), and — in Phase 3 —
 * precompute the RGB pHash for every variant image to the spec in
 * /shared/HASHING.md. It is runnable standalone as a cron/job.
 */

import type { CardSource } from './sources/types.js';

// Registry of available sources. Phase 1 registers the first concrete source.
const sources: Record<string, () => CardSource> = {};

async function main(): Promise<void> {
  const requested = process.argv[2];
  console.log('[ingest] Phase 0 stub — ingestion pipeline lands in Phase 1.');
  if (requested) {
    console.log(`[ingest] requested source: ${requested}`);
  }
  console.log(`[ingest] registered sources: ${Object.keys(sources).join(', ') || '(none yet)'}`);
}

void main();
