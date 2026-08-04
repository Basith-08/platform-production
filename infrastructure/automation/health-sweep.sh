#!/usr/bin/env bash
#
# Sweeps every deployed application and platform service, reporting any
# container that is not "healthy" and not "running". Intended for use
# during docs/04-operations/OPS-010-maintenance.md routine checks, or as a
# quick first diagnostic step in docs/04-operations/OPS-008-incident-response.md.
#
# Reference: docs/01-architecture/ARCH-009-monitoring-architecture.md

set -euo pipefail

echo "Scanning platform services..."
for dir in /srv/platform/*/; do
  [ -f "${dir}compose.yaml" ] || continue
  (cd "${dir}" && docker compose ps --format "table {{.Name}}\t{{.Status}}")
done

echo ""
echo "Scanning applications..."
for dir in /srv/apps/*/; do
  [ -f "${dir}compose.yaml" ] || continue
  (cd "${dir}" && docker compose ps --format "table {{.Name}}\t{{.Status}}")
done

echo ""
echo "Containers not reporting healthy or running:"
docker ps --filter "health=unhealthy" --format "{{.Names}}: {{.Status}}"
docker ps -a --filter "status=exited" --format "{{.Names}}: {{.Status}}"
