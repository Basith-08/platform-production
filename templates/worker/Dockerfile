# Worker template Dockerfile.
#
# Reference: docs/03-standards/STD-004-docker-image-standard.md

FROM node:20.11-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20.11-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
RUN useradd --system --uid 1001 appuser
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
USER appuser
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=15s \
  CMD node dist/healthcheck.js
CMD ["node", "dist/worker.js"]
