# infra

Self-hosting / deployment for OP Scanner.

## Files

- `docker-compose.yml` — Postgres + API (the ingestion job is added in Phase 1).
- `.env.example` — template for `infra/.env`. **`infra/.env` is gitignored; never commit secrets.**

## Run

```bash
cp infra/.env.example infra/.env      # then edit values
cd infra
docker compose up --build
```

- API: http://localhost:3000  (health: `/health`, readiness: `/health/ready`, docs: `/docs`)
- Postgres: published on `localhost:${POSTGRES_PORT}` (default 5432)

The API container runs `prisma migrate deploy` on startup, then serves. Postgres
data persists in the `pgdata` named volume.

## Notes

- `DATABASE_URL` in `infra/.env` uses host `postgres` (the compose service name).
  When running the API or Prisma from your **host machine** instead, use the
  `localhost`-based `DATABASE_URL` from `server/.env`.
- To wipe local data: `docker compose down -v` (removes the `pgdata` volume).
