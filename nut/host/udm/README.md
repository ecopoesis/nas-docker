# UDM Pro clean shutdown

UniFi OS has **no built-in NUT client** (it remains an open, unfulfilled feature
request). The most robust option that survives firmware updates is to have
server03's `upsmon`, on low battery, SSH into the UDM Pro and run UniFi's own
poweroff command — nothing is installed on the UDM itself.

This is already wired into `../server03/nut-shutdown.sh` (it runs
`ssh root@<UDM> ubnt-systool poweroff`). It is **best-effort and fail-fast**: if the
SSH key isn't set up or the UDM is unreachable, it is skipped and server03 still
shuts down normally. It stays a no-op until you complete the steps below.

## One-time setup

1. **Enable SSH on the UDM Pro**
   UniFi Network → Settings → System → Advanced → enable **SSH**, and set an SSH
   password (you'll use it once to install the key).

2. **Create an SSH key for server03's root user and copy it to the UDM**
   On **server03**:
   ```bash
   sudo ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519   # if root has no key yet
   sudo ssh-copy-id -i /root/.ssh/id_ed25519.pub root@192.168.1.1
   ```

3. **Test the poweroff path without actually powering off**
   ```bash
   sudo ssh -o BatchMode=yes root@192.168.1.1 'ubnt-systool --help; echo KEY_OK'
   ```
   If you see `KEY_OK`, key auth works. (`ubnt-systool poweroff` is the real command
   `nut-shutdown.sh` runs — don't run it now unless you want the UDM to power off.)

## Caveats

- On some UniFi OS versions, keys added to `/root/.ssh/authorized_keys` are wiped by
  firmware updates. If shutdown stops working after an update, re-run step 2. (The
  `unifi-utilities/unifios-utilities` "on-boot-script" project can persist it, but the
  SSH-key approach above is the simplest to start with.)
- Switches and APs are stateless PoE devices — they don't need a clean shutdown and
  will simply ride the UPS until it dies. Only the UDM Pro (with storage) benefits.
