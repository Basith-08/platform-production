#!/usr/bin/env bash
# Prepare Traefik's persistent bind directory without touching its contents.

set -euo pipefail

COMPONENT_DIR="${COMPONENT_DIR:-/srv/platform/traefik}"
install -d -o deploy -g deploy -m 0750 "${COMPONENT_DIR}/certs"
