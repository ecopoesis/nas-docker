#!/usr/bin/env bash
#
# upsmon SHUTDOWNCMD for server03 (the primary).
# Runs once, after upsmon has waited HOSTSYNC seconds for secondaries to disconnect,
# i.e. homebridge01 has already received the FSD signal and is shutting itself down.
#
# Steps:
#   1. Best-effort: tell the UDM Pro to power off. Backgrounded and timeout-guarded so a
#      missing SSH key or an unreachable gateway can NEVER block this host's shutdown.
#      (No-op until you set up key auth — see ../udm/README.md.)
#   2. Halt this host.
#
# NOTE on UPS "kill power": the NUT driver lives in a container, so this host does not
# run upsdrvctl and therefore does NOT command the UPS to cut its output at the end of
# shutdown. The accepted trade-off is to set the BIOS to "Restore on AC Power Loss =
# Power On" so the machine reboots when mains returns. See ../../README.md.

UDM_HOST="@UDM_HOST@"

logger -t nut-shutdown "Low battery: powering off UDM (best-effort) then halting host"

timeout 15 ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 \
  "root@${UDM_HOST}" 'ubnt-systool poweroff' >/dev/null 2>&1 &

# Small head start so the UDM begins its own shutdown before we drop the host.
sleep 8

/sbin/shutdown -h +0
