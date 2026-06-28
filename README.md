# OP Scanner

Cross-platform manager for a personal **One Piece TCG** collection: fast offline
camera scanning (mobile), offline-first collection management, cloud sync, web
access, and market pricing.

> **Status:** Phase 0 — scaffold (see [Build order](#build-order)). The backend
> runs and the Flutter app launches; catalog, accounts/sync, and scanning land
> in later phases.

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

### 3. Flutter app

```bash
cd app
flutter pub get
flutter run            # mobile device/emulator
flutter run -d chrome  # web
```

Scanning is mobile-only and is feature-flagged off on web (see
`app/lib/src/core/platform.dart`).

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
- **Phase 1 — Catalog + ingestion** — pluggable `CardSource`, catalog API +
  `/catalog/sync`, browsable/filterable card list with prices.
- **Phase 2 — Accounts + collection + sync** — auth, offline-first sync engine.
- **Phase 3 — Scanning** — camera → OpenCV rectify → ML Kit OCR → RGB pHash →
  local match; hashes precomputed in `/ingest` to `/shared/HASHING.md`.
- **Phase 4 — Polish** — price history, stats, settings.

See the project plan for full detail on each phase and its checkpoint.
