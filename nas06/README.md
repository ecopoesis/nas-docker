# nas06

TrueNAS SCALE media server (192.168.1.5). There's one folder per stack. Komodo
deploys each folder from this repo; `komodo/` itself runs as a TrueNAS custom app.

| Stack | Apps | Ports |
|---|---|---|
| `komodo/` | Komodo core, periphery, mongo | 9120 |
| `plex/` | Plex | 32400 (host network) |
| `jellyfin/` | Jellyfin | 8096, 7359/udp |
| `arr/` | SABnzbd, Sonarr, Radarr, Prowlarr | 10000, 10004, 10002, 9696 |
| `qbittorrent/` | qBittorrent (manual torrents) | 8090, 6881 |
| `resilio/` | Resilio Sync | 10006, 55555 |

## Storage

- `${CONFIG_ROOT:-/mnt/tank/config}/<app>`: app config, one dataset per app. Moves to
  the SSD pool later.
- `${MEDIA_ROOT:-/mnt/tank/media}`: `movies/`, `tv/`, `roms/`, `downloads/{complete,incomplete,torrents,resilio}`.
  Plex and Jellyfin mount it read-only.
- Every app runs as TrueNAS's `apps` user (568:568), with TZ `Etc/UTC`.

## Migration notes (from the QNAP)

Container paths match the QNAP's (`/tv`, `/movies`, `/downloads`, Plex `/data`),
so the migrated databases work unchanged. Later improvement: switch the arr apps
to a single `/data` mount so imports are hard links instead of copies.
