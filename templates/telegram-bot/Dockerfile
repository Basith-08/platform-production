# Telegram bot template Dockerfile.
#
# The build is configured through build.env. Change that file when the
# application uses another language or framework; the workflow passes the
# same values to this Dockerfile.
#
# Reference: docs/03-standards/STD-004-docker-image-standard.md

ARG BUILD_IMAGE=node:20.11-slim
ARG RUNTIME_IMAGE=node:20.11-slim

FROM ${BUILD_IMAGE} AS build
WORKDIR /app
COPY . .
ARG INSTALL_COMMAND="npm ci"
ARG BUILD_COMMAND="npm run build"
ARG RUNTIME_PREPARE_COMMAND="cp -a dist node_modules /runtime/"
RUN sh -c "${INSTALL_COMMAND}"
RUN sh -c "${BUILD_COMMAND}"
RUN mkdir -p /runtime && sh -c "${RUNTIME_PREPARE_COMMAND}"

FROM ${RUNTIME_IMAGE} AS runtime
WORKDIR /app
ARG START_COMMAND="node dist/main.js"
ARG HEALTHCHECK_COMMAND="node dist/healthcheck.js"
ENV NODE_ENV=production \
    START_COMMAND="${START_COMMAND}" \
    HEALTHCHECK_COMMAND="${HEALTHCHECK_COMMAND}"
COPY --from=build --chown=1001:1001 /runtime/ ./
USER 1001:1001
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=15s \
  CMD ${HEALTHCHECK_COMMAND}
CMD ["sh", "-c", "exec $START_COMMAND"]
