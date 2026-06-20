#!/usr/bin/env bash
#
# Native NUT client (upsmon) for server03 — the PRIMARY.
# It monitors the containerized upsd on localhost and, on low battery, runs the
# shutdown sequence: waits for secondaries (homebridge01) to disconnect, then runs
# nut-shutdown.sh (optionally powers off the UDM, then halts this host).
#
# upsmon runs natively on the host on purpose: the process that powers off the box
# must be a root process owned by the host's init, independent of the Docker daemon
# (which may itself be dying during a power event).
#
# Usage:
#   sudo NUT_PASSWORD='your-strong-password' bash install.sh
#
# Optional overrides:
#   UPSD_HOST=127.0.0.1   # where the containerized upsd is published
#   UDM_HOST=192.168.1.1  # UniFi gateway to power off (best-effort; see host/udm)

set -euo pipefail

: "${NUT_PASSWORD:?Set NUT_PASSWORD to match the value set in the Portainer stack}"
UPSD_HOST="${UPSD_HOST:-127.0.0.1}"
UDM_HOST="${UDM_HOST:-192.168.1.1}"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo." >&2
  exit 1
fi

echo ">> Installing nut-client ..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y nut-client

echo ">> Writing /etc/nut/nut.conf (netclient) ..."
install -m 0640 -o root -g nut /dev/stdin /etc/nut/nut.conf <<'EOF'
# Managed by nas-docker/nut/host/server03/install.sh
# upsd runs in a container; this host only runs upsmon -> netclient.
MODE=netclient
EOF

echo ">> Writing /etc/nut/upsmon.conf (primary) ..."
install -m 0640 -o root -g nut /dev/stdin /etc/nut/upsmon.conf <<EOF
# Managed by nas-docker/nut/host/server03/install.sh
RUN_AS_USER root
MONITOR gxt5@${UPSD_HOST} 1 upsmon ${NUT_PASSWORD} primary
MINSUPPLIES 1
SHUTDOWNCMD "/usr/local/sbin/nut-shutdown.sh"
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
FINALDELAY 5
POWERDOWNFLAG /etc/killpower
EOF

echo ">> Installing /usr/local/sbin/nut-shutdown.sh ..."
sed "s|@UDM_HOST@|${UDM_HOST}|g" "$(dirname "$0")/nut-shutdown.sh" \
  > /usr/local/sbin/nut-shutdown.sh
chmod 0755 /usr/local/sbin/nut-shutdown.sh

echo ">> Enabling and starting nut-monitor ..."
systemctl enable nut-monitor.service >/dev/null 2>&1 || true
systemctl restart nut-monitor.service

echo ">> Done. Status:"
sleep 2
upsc gxt5@"${UPSD_HOST}" ups.status 2>/dev/null || true
systemctl --no-pager --lines=5 status nut-monitor.service || true
