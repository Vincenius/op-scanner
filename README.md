# OP Scanner

Cross-platform manager for a personal **One Piece TCG** collection: fast offline
camera scanning (mobile), offline-first collection management, cloud sync, web
access, and market pricing.

> **Status:** Phase 3 — scanning + tags (see [Build order](#build-order)). Catalog
> browse, accounts, offline-first collection sync, **tags ("deck boxes")**, and
> the **on-device recognizer** (RGB pHash precompute + match) are done. The live
> camera scan flow is built behind the mobile feature-flag and needs on-device
> validation (camera/ML Kit can't run in CI).

## Repo layout

```
/app       Flutter client (mobile + web) — Riverpod, go_router
/server    Fastify API + Prisma (PostgreSQL), TypeScript (ESM, strict)
/ingest    Card-data ingestion + pHash precompute (TypeScript) — pluggable CardSource
/shared    Shared TS types / OpenAPI schema; source of generated Dart models
/infra     docker-compose, env templates, deploy notes
```

`/server`, `/ingest`, and `/shared` are npm **workspaces** (root `package.json`).
`/app` is a standalone Flutter project.

## Prerequisites

- Node.js ≥ 20 (developed on 24)
- Docker + Docker Compose v2
- Flutter (stable) + Dart 3 — only needed to work on `/app`

## Quick start

### 1. Backend (API + Postgres) via Docker

```bash
cp infra/.env.example infra/.env        # then edit secrets
cd infra
docker compose up --build
```

- API → http://localhost:3000
  - `GET /health` — liveness
  - `GET /health/ready` — readiness (checks DB)
  - `/docs` — Swagger UI · `/docs/json` — OpenAPI spec
- Postgres → `localhost:5432`

The API container applies `prisma migrate deploy` on startup. Data persists in
the `pgdata` volume (`docker compose down -v` wipes it).

### 2. Backend locally (without Docker)

Start just Postgres (`docker compose up -d postgres`), then:

```bash
cp server/.env.example server/.env       # uses host=localhost
npm install
npm run prisma:generate
npm run prisma:migrate                    # dev migrations
npm run dev:server
```

### 3. Ingest the card data

Populate the catalog (sets, cards, alt-art variants, TCGPlayer USD prices). Needs
Postgres up and an apitcg.com API key in `ingest/.env` (`APITCG_API_KEY`).

```bash
cp ingest/.env.example ingest/.env      # set APITCG_API_KEY + DATABASE_URL
npm run ingest                          # live: apitcg metadata/images + optcgapi prices
# or, offline sample data (no key/network):
npm run -w @op-scanner/ingest ingest -- fixture
```

Metadata/images come from apitcg.com; prices from optcgapi.com. Each printing
(base, parallel/alt-art, …) is stored as its own `card_variant`, and prices are
keyed to the variant — so alt-arts get their own price.

Precompute recognition hashes (per /shared/HASHING.md) for the scanner:

```bash
npm run -w @op-scanner/ingest ingest -- phash            # all variants
npm run -w @op-scanner/ingest ingest -- phash OP01       # one set
```

These sync to the client (`/catalog/sync`) for fully offline matching. Tune/check
matching with the eval harness: `cd app && dart run tool/eval.dart <db.json> <imagesDir>`.

### 4. Flutter app

```bash
cd app
flutter pub get
flutter run -d chrome   # web
flutter run             # mobile device/emulator (Android emulator: pass
                        # --dart-define=API_BASE_URL=http://10.0.2.2:3000)
```

Open the app and tap **Sync catalog** to mirror the catalog into the local
(drift) DB; after that, browse/search/filter works offline. Card images are
proxied + cached through the API (`/img/...`), and thumbnails are bulk-prefetched
on sync. Scanning is mobile-only and feature-flagged off on web (see
`app/lib/src/core/platform.dart`).

Use the **Collection** tab to sign in / create an account, then add cards (from a
card's detail page) with a condition. Edits write to the local DB immediately and
sync to the server in the background (offline-first, last-write-wins); the same
account sees the collection on any device. Tokens are stored in secure storage.

**Tags ("deck boxes"):** create tags and assign them to collection entries (from
the entry's ⋯ menu, or during scanning so every scanned card is tagged). Filter
the collection by tag, and a card's detail page shows which boxes it's in. Tags
sync across devices like the collection.

**Scanning (mobile):** open **Scan** and point at a card — it captures
**automatically** (no tap). Each frame is de-skewed (OpenCV: Canny → contours →
largest card quad → perspective warp), ML Kit reads the card code, and the art is
perceptually hashed + matched offline (alt-arts included). Confident, stable
matches are added to your collection with the active scan tag; per-card debounce
avoids duplicates. Toggle **Auto-add** off to confirm each card with a tap.
Hidden on web.

> Running the OpenCV rectifier test locally needs the dartcv native lib: download
> `libdartcv-linux-x64.tar.gz` (dartcv release matching opencv_dart's
> `dartcv_version`) and run with `DARTCV_LIB_PATH=/path/to/libdartcv.so`. A device
> build links it automatically; a plain `flutter test` just skips that test.

## Environment & secrets

- Secrets live only in `.env` files, which are **gitignored**. Templates:
  `infra/.env.example`, `server/.env.example`, `ingest/.env.example`.
- `infra/.env` `DATABASE_URL` uses host `postgres` (compose network);
  `server/.env` uses `localhost` (running from your machine).
- Never commit real keys/URLs.

## Common scripts (run from repo root)

```bash
npm run build         # build all TS workspaces
npm run typecheck     # typecheck all TS workspaces
npm run dev:server    # run the API in watch mode
npm run prisma:migrate  # create/apply a dev migration
npm run ingest        # run the ingestion job (stub until Phase 1)
```

## Build order

- **Phase 0 — Scaffold** ✅ monorepo, compose (postgres + api), Prisma schema,
  Fastify health check, Flutter skeleton.
- **Phase 1 — Catalog + ingestion** ✅ pluggable `CardSource` (apitcg + optcgapi),
  catalog API + `/catalog/sync`, image proxy, offline drift mirror, browsable/
  searchable/filterable catalog with images + USD prices.
- **Phase 2 — Accounts + collection + sync** ✅ email/password auth (JWT +
  rotating refresh), collection model + `POST /collection/sync` (LWW, soft
  deletes, idempotent), offline-first client sync engine + collection UI.
- **Phase 3 — Scanning + tags** ◑ recognizer (RGB pHash + on-device match, per
  `/shared/HASHING.md`), OpenCV perspective de-skew, continuous auto-capture, eval
  harness, and tags — all built & validated (the OpenCV de-skew is validated on
  real skewed cards). Live camera capture itself still needs on-device testing.
- **Phase 4 — Polish** — price history, stats, settings.

See the project plan for full detail on each phase and its checkpoint.
