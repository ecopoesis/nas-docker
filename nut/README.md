# NUT — UPS-triggered clean shutdown

Brings every machine down cleanly when the **Vertiv GXT5** UPS (USB → server03) is
about to run out of battery.

## Topology

```
            Vertiv GXT5 (USB)
                  │
            ┌─────┴───────────────────────────────┐
            │ server03 (192.168.1.4)               │
            │                                      │
            │  ┌────────────────────────────────┐  │
            │  │ nut-upsd container (Portainer)  │  │   ← this stack
            │  │  usbhid-ups driver + upsd :3493 │  │
            │  └────────────────────────────────┘  │
            │  upsmon (native, PRIMARY) ──────────┐ │
            └──────────────────────────────────── │ ┘
                  │ tcp/3493                       │ runs SHUTDOWNCMD
                  │                                ▼
     ┌────────────┴───────────┐            shuts down server03
     ▼                        ▼            + SSH poweroff UDM
 homebridge01            UDM Pro
 (192.168.16.40)         (192.168.1.1)
 upsmon (native,         powered off via
  SECONDARY)             ssh ubnt-systool poweroff
 shuts itself down       (best-effort)
```

- **`upsd` + driver are containerized** (this stack) — that's the part you deploy in
  Portainer.
- **`upsmon` runs natively on each Ubuntu host.** The process that actually powers a
  box off must be a host root process, independent of the Docker daemon (which may be
  dying during a power event). See the fragility discussion in the repo history.
- One shared monitor account (`upsmon` / `NUT_PASSWORD`) is used by every upsmon.

## 1. Deploy the NUT server stack (server03, via Portainer)

**Prerequisite (one-time, on server03):** the stack bind-mounts the GXT5 driver
definition from the host. Place it first:

```bash
sudo mkdir -p /opt/containers/nut
sudo cp nut/local/ups.conf /opt/containers/nut/ups.conf
```

Portainer → **Stacks → Add stack → Git repository**:

| Field | Value |
|-------|-------|
| Repository URL | `https://github.com/ecopoesis/nas-docker` |
| Compose path | `nut/docker-compose.yml` |
| Environment variables | add `NUT_PASSWORD` = a strong password |

Deploy. Then verify the UPS is being read (from server03):

```bash
docker exec nut-upsd upsc gxt5
```

You should see `ups.status: OL`, `battery.charge: 100`, `battery.runtime` (seconds),
`ups.model: GXT5 LI`, etc. (Verified working on this unit: runtime is reported
correctly in seconds, ~49 min at full charge.) If you get `Driver not connected`,
confirm `lsusb` shows `10af:1000` and the container has the USB device
(`devices: /dev/bus/usb`).

> **Why `/opt/containers/nut/ups.conf` exists:** the GXT5 (`10af:1000`) isn't
> auto-claimed by `usbhid-ups` — it must be forced with an explicit `productid = 1000`,
> which this image's env-only config can't express. The driver section is therefore
> bind-mounted from a pre-created host file to `/etc/nut/local/ups.conf` (the image
> copies it to `/etc/nut/ups.conf` on startup). A pre-created absolute-path file is used
> because Portainer doesn't render inline compose `configs`, a missing bind source gets
> created as a directory, and a read-only *directory* mount makes the image abort.
> Shutdown triggers on the UPS's own `LB` low-battery flag regardless of the runtime
> number.

> Passwords stay out of git: `NUT_PASSWORD` is set in the Portainer stack environment
> (or a local, git-ignored `nut/.env` — see `.env.example`). The image can also read a
> Docker secret named `nut-upsd-password` instead.

## 2. Install the shutdown agent on each host (native upsmon)

Use the **same** `NUT_PASSWORD` everywhere.

**server03** (primary — monitors the local container, shuts down the host, powers off
the UDM):
```bash
cd nut/host/server03
sudo NUT_PASSWORD='your-strong-password' bash install.sh
```

**homebridge01** (secondary — monitors server03 over the network):
```bash
cd nut/host/homebridge01
sudo NUT_PASSWORD='your-strong-password' bash install.sh
```

Each script installs `nut-client`, writes `/etc/nut/nut.conf` (`MODE=netclient`) and
`/etc/nut/upsmon.conf`, and enables `nut-monitor`. Check status:
```bash
systemctl status nut-monitor
upsc gxt5@192.168.1.4 ups.status   # from either host
```

> **Cross-VLAN note:** homebridge01 (`192.168.16.x`) reaches server03 (`192.168.1.x`)
> through the UDM. If `upsc gxt5@192.168.1.4` times out from homebridge01, add a UniFi
> firewall rule allowing `192.168.16.0/24 → 192.168.1.4 tcp/3493`.

## 3. UDM Pro shutdown (optional but recommended)

See [`host/udm/README.md`](host/udm/README.md). One-time SSH-key setup; until then the
UDM poweroff is a harmless no-op and server03 still shuts down fine.

## 4. BIOS: auto power-on (do this on server03 and homebridge01)

Because the driver is containerized, NUT does **not** tell the UPS to cut power at the
end of shutdown ("kill power" is skipped). Consequence: after a clean shutdown the
machines stay off until mains is restored. Set each machine's BIOS/UEFI to
**Restore on AC Power Loss = Power On** so they boot automatically when power returns.

## How the shutdown actually fires

1. Mains fails → UPS reports `OB` (on battery). Everything keeps running.
2. Battery drains to the UPS's low-battery threshold → UPS reports `OB LB`.
3. server03's primary `upsmon` sets the **FSD** flag on `upsd`.
4. homebridge01 (secondary) sees FSD → runs its `SHUTDOWNCMD` → halts.
5. server03 waits `HOSTSYNC` (15s) for the secondary to disconnect, then runs
   `nut-shutdown.sh` → SSH-poweroff the UDM (best-effort) → halts server03.
6. Power returns → BIOS auto power-on brings the machines back.

## Files

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | NUT server stack (driver + upsd) for Portainer |
| `local/ups.conf` | GXT5 driver def; copy to `/opt/containers/nut/ups.conf` on server03 |
| `.env.example` | template for `NUT_PASSWORD` |
| `host/server03/install.sh` | native upsmon (primary) installer |
| `host/server03/nut-shutdown.sh` | primary SHUTDOWNCMD (UDM poweroff + halt) |
| `host/homebridge01/install.sh` | native upsmon (secondary) installer |
| `host/udm/README.md` | UDM Pro SSH-poweroff setup |
