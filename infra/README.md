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

This starts Postgres + the API. op-scanner gets its **own** database container,
isolated from anything else on the host.

- API: http://localhost:${API_PORT}  (health: `/health`, readiness: `/health/ready`, docs: `/docs`)
- Postgres: bundled. The API talks to it over the internal compose network
  (host `postgres`). It is also published on `127.0.0.1:${POSTGRES_PORT}`
  (default 5433) for optional host-side access — set `POSTGRES_PORT` to any free
  port if that one is taken.

The API container runs `prisma migrate deploy` against `DATABASE_URL` on startup,
then serves. Postgres data persists in the `pgdata` named volume.

## Using an existing Postgres instead

Only do this for a Postgres you intentionally want to share (not another app's
private DB). Point `DATABASE_URL` at it and start just the API:

```bash
docker compose up --build --no-deps api
```

- DB on the **Docker host** → `@host.docker.internal:<port>` (that Postgres must
  listen on the docker bridge and allow its subnet in `pg_hba.conf`).
- DB on **another server** → `@that-host:<port>`.

The database and role in `DATABASE_URL` must already exist — migrations create
the *tables*, not the database/role.

## Notes

- When running the API or Prisma from your **host machine** instead of compose,
  use the `localhost`-based `DATABASE_URL` from `server/.env` (host
  `localhost:${POSTGRES_PORT}`).
- To wipe local data: `docker compose down -v` (removes the `pgdata` volume).
