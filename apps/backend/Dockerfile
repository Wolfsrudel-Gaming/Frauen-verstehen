# syntax=docker/dockerfile:1
# Build context must be the monorepo root (pnpm workspace install needs the
# root lockfile + all workspace package.json files).

FROM node:20-alpine AS base
RUN corepack enable
WORKDIR /repo

FROM base AS deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/backend/package.json apps/backend/package.json
COPY apps/web/package.json apps/web/package.json
RUN pnpm install --frozen-lockfile

FROM deps AS build
COPY apps/backend apps/backend
RUN pnpm --filter backend build

FROM base AS runtime
ENV NODE_ENV=production
COPY --from=deps /repo/node_modules /repo/node_modules
COPY --from=deps /repo/apps/backend/node_modules /repo/apps/backend/node_modules
COPY --from=build /repo/apps/backend/dist /repo/apps/backend/dist
COPY apps/backend/package.json apps/backend/package.json
WORKDIR /repo/apps/backend
EXPOSE 3001
CMD ["node", "dist/index.js"]
