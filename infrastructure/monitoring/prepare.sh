#!/usr/bin/env bash
# Prepare monitoring bind directories without touching their contents.

set -euo pipefail

COMPONENT_DIR="${COMPONENT_DIR:-/srv/platform/monitoring}"
install -d -o deploy -g deploy -m 0755 "${COMPONENT_DIR}/beszel-data"
install -d -o deploy -g deploy -m 0755 "${COMPONENT_DIR}/kuma-data"
