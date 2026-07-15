#!/usr/bin/env bash
#
# Creates the shared Docker networks required before any platform service
# or application is started. Idempotent: safe to re-run.
#
# Reference: docs/01-architecture/ARCH-004-network-architecture.md
#            docs/03-standards/STD-007-network-standard.md

set -euo pipefail

create_network() {
  local name="$1"
  if docker network inspect "${name}" >/dev/null 2>&1; then
    echo "Network '${name}' already exists — skipping."
  else
    docker network create "${name}"
    echo "Created network '${name}'."
  fi
}

# edge: shared network Traefik and every routed application attach to.
# Only Traefik publishes host ports 80/443 onto this network's containers.
create_network "edge"

# platform-internal: shared network for platform services (Beszel, Uptime
# Kuma) that need to reach each other without joining application networks.
create_network "platform-internal"

echo "Shared networks ready."
