#!/usr/bin/env bash
# Lightweight terminal monitoring for the production VPS.
# This intentionally has no daemon, database, or web dashboard.

set -euo pipefail

echo "== host =="
hostname --fqdn 2>/dev/null || hostname
uptime
free -h

echo
echo "== storage =="
df -hT / /srv 2>/dev/null || df -hT /

echo
echo "== docker containers =="
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

echo
echo "== docker memory =="
if docker ps -q | grep -q .; then
  docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}'
else
  echo "No running containers."
fi
