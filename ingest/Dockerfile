# Build context is the repo ROOT (see infra/docker-compose.yml -> ingest.build.context: ..)
# so the npm workspace (root manifest + /shared + /server + /ingest) is available.
#
# This image is a ONE-OFF JOB, not a long-running service: it pulls catalog
# metadata + prices (and optionally pHashes) into DATABASE_URL, then exits.
# Run it via `docker compose run --rm ingest [live|fixture|phash]`.

# ---- Builder ----
FROM node:22-alpine AS builder
WORKDIR /repo

# Install workspace deps using only the manifests first (better layer caching).
COPY package.json package-lock.json ./
COPY shared/package.json ./shared/package.json
COPY server/package.json ./server/package.json
COPY ingest/package.json ./ingest/package.json
RUN npm ci

# Sources: the ingest job + shared lib, plus the server's Prisma schema. The
# Prisma client is generated from that schema and shared across workspaces via
# the hoisted node_modules; ingest itself imports no server code.
COPY shared ./shared
COPY server/prisma ./server/prisma
COPY ingest ./ingest

# Build shared, generate the Prisma client, then compile the ingest job.
RUN npm run -w @op-scanner/shared build \
  && npm run -w @op-scanner/server prisma:generate \
  && npm run -w @op-scanner/ingest build

# ---- Runner ----
FROM node:22-alpine AS runner
WORKDIR /repo
ENV NODE_ENV=production

# Full node_modules (incl. the generated Prisma client + sharp's native binary).
COPY --from=builder /repo/node_modules ./node_modules
COPY --from=builder /repo/package.json ./package.json
COPY --from=builder /repo/shared ./shared
COPY --from=builder /repo/server/prisma ./server/prisma
COPY --from=builder /repo/ingest ./ingest

WORKDIR /repo/ingest
# Default profile is "live"; override the arg to pick another, e.g.
#   docker compose run --rm ingest fixture
ENTRYPOINT ["node", "dist/index.js"]
CMD ["live"]
