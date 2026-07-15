# infrastructure/networks/

Defines and creates the shared Docker networks the platform depends on: `edge` and `platform-internal`.

Every application's own private `<app-name>-internal` network is created by that application's own `compose.yaml`, not here — this directory only owns networks shared across multiple services.

Run `./create-networks.sh` once during [OPS-001 — Server Provisioning](../../docs/04-operations/OPS-001-server-provisioning.md) (Step 8) and as part of [OPS-009 — Disaster Recovery](../../docs/04-operations/OPS-009-disaster-recovery.md). The script is idempotent.

See [ARCH-004 — Network Architecture](../../docs/01-architecture/ARCH-004-network-architecture.md) and [STD-007 — Network Standard](../../docs/03-standards/STD-007-network-standard.md) for the full topology and rules this implements.
