# Komodo (nas06)

Container manager. It deploys the other `nas06/<stack>/` folders straight from this
repo and redeploys them when a GitHub webhook reports a push.

- UI: http://192.168.1.5:9120 (user `admin`)
- State: `/mnt/tank/config/komodo/` (`mongo/`, `keys/`, `backups/`, `periphery/`)
- Secrets: `/mnt/tank/config/komodo/komodo.env` on nas06 only (template: `komodo.env.example`)

## Bootstrap

Komodo can't deploy itself, so this stack runs as a **TrueNAS custom app** named
`komodo` (Apps → Discover → Install via YAML), created from `docker-compose.yml`.
Updating it means pasting the new file into that app's Edit page, or doing the same
through the TrueNAS API.

## Adding a stack

1. Create `nas06/<stack>/docker-compose.yml`. Mount config from
   `${CONFIG_ROOT:-/mnt/tank/config}/<stack>`, never a hard-coded pool path, and
   create the dataset `tank/config/<stack>` first.
2. In Komodo: Stacks → New → server `nas06`, repo `ecopoesis/nas-docker`, branch
   `main`, run directory `nas06/<stack>`.
3. Optional: copy the stack's webhook URL into GitHub (Settings → Webhooks,
   content type `application/json`, secret = `KOMODO_WEBHOOK_SECRET`, push events).

## Moving config to the SSD pool

Replicate `tank/config` to the new pool, change `CONFIG_ROOT` everywhere it's set
(the TrueNAS app and each Komodo stack's environment), then redeploy.
