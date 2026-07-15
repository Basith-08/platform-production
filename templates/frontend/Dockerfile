# Frontend application template Dockerfile.
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
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/public ./public
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=15s \
  CMD node -e "require('http').get('http://localhost:3000/', r => process.exit(r.statusCode < 500 ? 0 : 1)).on('error', () => process.exit(1))"
CMD ["node", "server.js"]
