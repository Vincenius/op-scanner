# Build context is the repo ROOT (see infra/docker-compose.yml -> api.build.context: ..)
# so that the npm workspace (root manifest + /shared + /server) is available.

# ---- Builder ----
FROM node:22-alpine AS builder
WORKDIR /repo

# Install workspace deps using only the manifests first (better layer caching).
COPY package.json package-lock.json ./
COPY shared/package.json ./shared/package.json
COPY server/package.json ./server/package.json
COPY ingest/package.json ./ingest/package.json
RUN npm ci

# Bring in the sources needed to build the API.
COPY shared ./shared
COPY server ./server

# Generate the Prisma client and compile TypeScript.
RUN npm run -w @op-scanner/shared build \
  && npm run -w @op-scanner/server prisma:generate \
  && npm run -w @op-scanner/server build

# ---- Runner ----
FROM node:22-alpine AS runner
WORKDIR /repo
ENV NODE_ENV=production

# Full node_modules (incl. generated Prisma client + the prisma CLI used by the
# entrypoint to run migrations) — image size is a non-issue for self-hosting.
COPY --from=builder /repo/node_modules ./node_modules
COPY --from=builder /repo/package.json ./package.json
COPY --from=builder /repo/shared ./shared
COPY --from=builder /repo/server ./server

WORKDIR /repo/server
RUN chmod +x docker-entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["./docker-entrypoint.sh"]
