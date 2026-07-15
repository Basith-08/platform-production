# infrastructure/compose/

Reserved for Compose fragments shared across more than one platform service, should that need arise (for example, a common logging or labeling fragment included via `include:` in multiple `infrastructure/*/compose.yaml` files).

At present, every platform service under `infrastructure/` (`traefik/`, `monitoring/`, `backup/`) is fully self-contained in its own `compose.yaml`, and no shared fragment exists yet — introducing one here is deferred until a second platform service genuinely needs to share Compose configuration, per the Operational Simplicity principle in [ARCH-001 — Platform Vision](../../docs/01-architecture/ARCH-001-platform-vision.md).

Network topology shared across services (`edge`, `platform-internal`) is defined in [`infrastructure/networks/`](../networks/), not here — this directory is reserved specifically for Compose *service* definitions, not network definitions.
