#!/usr/bin/env bash
#
# Native NUT client (upsmon) for homebridge01 — a SECONDARY.
# It monitors server03's containerized upsd over the network and, when the primary
# declares a forced shutdown (FSD) on low battery, halts this host.
#
# Usage:
#   sudo NUT_PASSWORD='your-strong-password' bash install.sh
#
# Optional override:
#   UPSD_HOST=192.168.1.4   # server03's LAN IP (default)

set -euo pipefail

: "${NUT_PASSWORD:?Set NUT_PASSWORD to match the value set in the Portainer stack}"
UPSD_HOST="${UPSD_HOST:-192.168.1.4}"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo." >&2
  exit 1
fi

echo ">> Checking reachability of upsd at ${UPSD_HOST}:3493 ..."
if ! timeout 5 bash -c "</dev/tcp/${UPSD_HOST}/3493" 2>/dev/null; then
  echo "!! WARNING: cannot reach ${UPSD_HOST}:3493 — check inter-VLAN firewall rules." >&2
  echo "   Continuing install anyway; upsmon will retry once connectivity exists." >&2
fi

echo ">> Installing nut-client ..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y nut-client

echo ">> Writing /etc/nut/nut.conf (netclient) ..."
install -m 0640 -o root -g nut /dev/stdin /etc/nut/nut.conf <<'EOF'
# Managed by nas-docker/nut/host/homebridge01/install.sh
MODE=netclient
EOF

echo ">> Writing /etc/nut/upsmon.conf (secondary) ..."
install -m 0640 -o root -g nut /dev/stdin /etc/nut/upsmon.conf <<EOF
# Managed by nas-docker/nut/host/homebridge01/install.sh
RUN_AS_USER root
MONITOR gxt5@${UPSD_HOST} 1 upsmon ${NUT_PASSWORD} secondary
MINSUPPLIES 1
SHUTDOWNCMD "/sbin/shutdown -h +0"
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
FINALDELAY 5
POWERDOWNFLAG /etc/killpower
EOF

echo ">> Enabling and starting nut-monitor ..."
systemctl enable nut-monitor.service >/dev/null 2>&1 || true
systemctl restart nut-monitor.service

echo ">> Done. Status:"
sleep 2
upsc gxt5@"${UPSD_HOST}" ups.status 2>/dev/null || true
systemctl --no-pager --lines=5 status nut-monitor.service || true
