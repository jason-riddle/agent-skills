---
name: adb
description: >
  Use this skill when working with the Android Debug Bridge (`adb`) — connecting
  to devices, enabling USB or wireless debugging, pushing/pulling files, running
  shell commands, installing apps, taking screenshots, reading device settings,
  or troubleshooting ADB connectivity. Triggers on requests like "connect to my
  Android phone via ADB", "enable USB debugging", "set up wireless ADB", "check
  if ADB is enabled", "push a file to the device", "install an APK", "run a
  command on the phone", "read device settings via adb", or any task involving
  `adb` and an Android device.
---

# adb

Connect to and control Android devices via the Android Debug Bridge (`adb`).

## Orientation

```bash
which -a adb
adb version
adb devices
adb devices -l    # long output with device details
```

## Key concepts

- **Device state**: `device` (ready), `offline` (unreachable), `unauthorized`
  (connected but not approved — a popup appears on the device asking to allow
  debugging; the user must accept)
- **Serial**: USB devices use a serial number; emulators use `emulator-NNNN`;
  wireless connections use `IP:PORT`
- **Multiple devices**: when more than one device is connected, ALL `adb`
  commands require `-s <serial>` to specify the target. Without it, commands
  fail with `error: more than one device/emulator`.
- **$ANDROID_SERIAL**: set this env var to target a device without `-s`.

## Device authorization

On first connection, the device shows an "Allow USB debugging?" popup with the
host's RSA key fingerprint. The user must tap "Allow" (or "OK"). Until then,
the device shows as `unauthorized` and all `adb shell` commands fail.

```
adb devices
# emulator-5554    unauthorized  ← user needs to accept popup on device
# ...after accepting...
# emulator-5554    device
```

To re-trigger the authorization popup:
```bash
adb kill-server
adb start-server
adb devices
```

"Always allow from this computer" checkbox prevents future prompts for that
key. To revoke all authorizations on the device:
```bash
adb -s <serial> shell settings put global adb_enabled 0
adb -s <serial> shell settings put global adb_enabled 1
# Or via Developer Options → "Revoke USB debugging authorizations"
```

## Checking and enabling USB debugging

### Read state
```bash
adb -s <serial> shell settings get global adb_enabled
# 1 = enabled, 0 = disabled
```

### Enable/disable via settings provider
```bash
adb -s <serial> shell settings put global adb_enabled 1   # enable
adb -s <serial> shell settings put global adb_enabled 0   # disable
```

Note: changing the setting via `settings put` may not flip the UI toggle in
Developer Options, but it affects the ADB daemon behavior. The UI toggle is
the canonical way to enable/disable; the settings command is a programmatic
alternative.

## Wireless debugging (Android 11+)

### Check state
```bash
adb -s <serial> shell settings get global adb_wifi_enabled
# 1 = enabled, 0 = disabled

adb -s <serial> shell settings get global adb_wifi_port
# port number, or null if not active
```

### Enable via settings provider
```bash
adb -s <serial> shell settings put global adb_wifi_enabled 1
```

This sets the flag but does NOT start the wireless ADB daemon or assign a
port on all devices. To reliably start wireless ADB:

### Classic method (`adb tcpip`) — works on all Android versions
```bash
# 1. Device must be connected via USB first
# 2. Switch ADB to TCP/IP mode on a specific port
adb -s <serial> tcpip 5555
# "restarting in TCP mode port: 5555"

# 3. Get the device's IP address
adb -s <serial> shell ip addr show wlan0 | grep "inet "
# Or for emulators:
adb -s <serial> shell ip addr show eth0 | grep "inet "

# 4. Connect wirelessly
adb connect <device_ip>:5555

# 5. Verify — now shows both USB and wireless connections
adb devices
```

### Wireless debugging pairing (Android 11+) — no USB cable needed
On the device, open Developer Options → Wireless debugging → "Pair device with
pairing code". This shows a pairing code, IP, and a **pairing port** (different
from the connection port).

```bash
# Pair using the pairing code shown on screen
adb pair <device_ip>:<pairing_port>
# Enter the 6-digit pairing code when prompted

# Non-interactive: pipe the code via stdin (here-string)
adb pair <device_ip>:<pairing_port> <<< "158875"

# After pairing, connect to the main port (shown at top of Wireless debugging page)
adb connect <device_ip>:<connection_port>
```

The pairing port and connection port are **different numbers**, and **both
ports change every time wireless debugging is toggled off/on or the device
reboots.** Never hardcode either port in scripts or notes — re-read or
re-scan each session.

Use the pairing port only for `adb pair`, then use the connection port for
`adb connect`. After `adb pair` succeeds, the pairing port is closed —
`adb connect` against it returns `Connection refused`.

### Discovering the connection port

The connection port is shown on the device's Wireless debugging screen. When
you cannot read it from the screen (device unattended, remote over Tailscale),
discover it from the host:

1. **mDNS (same subnet only):** `adb mdns services` lists `adb-tls-connect`
   services with their port. Fails across subnets/VPNs.
2. **Scan the port range (Tailscale / cross-subnet):** ADB wireless debugging
   ports are random high-numbered TCP ports. Scan the ephemeral range with a
   short per-port timeout and high parallelism. On the open port, `adb
   connect` will succeed; closed/refused ports skip.

```bash
# Fast parallel scan of the ephemeral range for a device IP
IP=100.100.10.224
# Scan 30000-60000 with 50 parallel workers, 0.2s timeout each
seq 30000 60000 | xargs -P50 -I{} bash -c '
  timeout 0.2 bash -c "</dev/tcp/'"$IP"'/{}/" 2>/dev/null && echo "OPEN: {}"
' 2>/dev/null
```

Then try `adb connect $IP:$PORT` on each open port until one reports
`connected`. Only the real ADB TLS port will accept the ADB handshake; other
open ports (if any) will refuse the connect. Expect 1 open port on a device
with wireless debugging active.

If scan finds nothing: wireless debugging may be off, the device may be
asleep, or the port is outside the scanned range. Ask the user to toggle
Wireless debugging off/on (which re-randomizes the port) and re-scan.

### Disable wireless debugging
```bash
adb -s <serial> shell settings put global adb_wifi_enabled 0
adb -s <serial> usb    # switch back to USB-only mode
```

### Switch from wireless back to USB
```bash
adb -s <serial> usb    # restart adbd listening on USB only
```

### Disconnect a wireless device
```bash
adb disconnect <device_ip>:<port>
adb disconnect          # disconnect all wireless devices
```

## Common device queries

### Device info
```bash
adb -s <serial> get-state              # device | offline | bootloader
adb -s <serial> get-serialno          # serial number
adb -s <serial> shell getprop ro.product.model     # model name
adb -s <serial> shell getprop ro.build.version.release  # Android version
adb -s <serial> shell getprop ro.product.manufacturer
adb -s <serial> shell wm size          # screen resolution
adb -s <serial> shell wm density       # screen density (DPI)
```

### List installed apps
```bash
adb -s <serial> shell pm list packages        # all packages
adb -s <serial> shell pm list packages -3     # third-party (user) only
adb -s <serial> shell pm list packages -s     # system only
adb -s <serial> shell pm list packages | grep chrome
```

### Read device settings
```bash
adb -s <serial> shell settings get global adb_enabled
adb -s <serial> shell settings get global adb_wifi_enabled
adb -s <serial> shell settings get global wifi_ip_address
adb -s <serial> shell settings list global    # all global settings
adb -s <serial> shell settings list system   # all system settings
adb -s <serial> shell settings list secure   # all secure settings
```

### ADB manager state (detailed debugging)
```bash
adb -s <serial> shell dumpsys adb
```
Shows connected keys, wireless AP info, pairing state, etc.

## File operations

### Push files to device
```bash
adb -s <serial> push local.txt /sdcard/Download/
adb -s <serial> push ./app.apk /sdcard/Download/
adb -s <serial> push --sync ./dir/ /sdcard/Download/dir/  # only changed files
```

### Pull files from device
```bash
adb -s <serial> pull /sdcard/Download/file.txt ./
adb -s <serial> pull -a /sdcard/DCIM/Photos/ ./photos/   # preserve timestamps
```

### Install / uninstall APKs
```bash
adb -s <serial> install app.apk               # install
adb -s <serial> install -r app.apk            # reinstall (keep data)
adb -s <serial> install -d app.apk            # allow version downgrade
adb -s <serial> uninstall com.example.app     # uninstall by package name
```

## Shell commands

```bash
adb -s <serial> shell                          # interactive shell
adb -s <serial> shell ls /sdcard/Download/    # one-shot command
adb -s <serial> shell "pm list packages -3"   # quote complex commands
adb -s <serial> shell "ip addr show wlan0"
```

### Useful shell commands
```bash
# Screenshots
adb -s <serial> shell screencap -p /sdcard/screenshot.png
adb -s <serial> pull /sdcard/screenshot.png .

# Screen recording (max 180s)
adb -s <serial> shell screenrecord /sdcard/video.mp4
# Ctrl+C to stop early
adb -s <serial> pull /sdcard/video.mp4 .

# Input events
adb -s <serial> shell input tap 500 800       # tap at coordinates
adb -s <serial> shell input text "hello"      # type text
adb -s <serial> shell input keyevent 3         # HOME key
adb -s <serial> shell input keyevent 4         # BACK key
adb -s <serial> shell input keyevent 66        # ENTER key

# Logcat
adb -s <serial> logcat                          # live logs
adb -s <serial> logcat -d                        # dump and exit
adb -s <serial> logcat -d *:E                    # errors only
adb -s <serial> logcat -d -s MyTag:V             # specific tag
adb -s <serial> logcat -d | grep "keyword"

# Reboot
adb -s <serial> reboot
adb -s <serial> reboot bootloader               # into bootloader/fastboot
adb -s <serial> reboot recovery                  # into recovery
```

### Keyevent reference

| Keyevent | Key |
|----------|-----|
| 3 | HOME |
| 4 | BACK |
| 5 | CALL |
| 6 | END_CALL |
| 24 | VOLUME_UP |
| 25 | VOLUME_DOWN |
| 26 | POWER |
| 27 | CAMERA |
| 66 | ENTER |
| 84 | SEARCH |
| 164 | MUTE |

## Port forwarding

```bash
# Forward local port to device port
adb -s <serial> forward tcp:8080 tcp:8080

# List all forwards
adb -s <serial> forward --list

# Remove a forward
adb -s <serial> forward --remove tcp:8080

# Remove all
adb -s <serial> forward --remove-all
```

## mDNS discovery

```bash
adb mdns check                    # check if mDNS is available
adb mdns services                  # list discovered ADB services on network
```

On Android 11+ with wireless debugging enabled, the device advertises itself
via mDNS. `adb mdns services` shows `adb-tls-connect` and `adb-tls-pairing`
services that can be used for auto-discovery.

## Gotchas

- **Multiple devices require `-s <serial>`.** When both USB and wireless
  connections exist, or multiple devices are connected, ALL commands fail
  without `-s`. Set `$ANDROID_SERIAL` to avoid repeating it.

- **`unauthorized` state requires user interaction on the device.** A popup
  appears asking "Allow USB debugging?" — the user must tap "Allow". There is
  no way to auto-accept from the host side (except with pre-trusted keys in
  `$ADB_VENDOR_KEYS`). The popup is a security feature.

- **The authorization popup may not appear if the screen is off.** Wake the
  device first (e.g. via `adb shell input keyevent 26` for POWER, or use the
  Android Remote Control MCP to press the power button). Then re-run
  `adb devices` to trigger the popup.

- **`adb tcpip` disconnects USB ADB.** After running `adb tcpip 5555`, the
  USB connection drops and only the wireless connection works. To restore
  USB mode, run `adb usb`.

- **Pairing port ≠ connection port.** The port shown in "Pair device with
  pairing code" is only for `adb pair`. After pairing, use the main port
  shown at the top of the Wireless debugging page for `adb connect`.
  Once pairing succeeds, the pairing port is closed and refuses connections.

- **`adb pair` accepts the pairing code via stdin.** For non-interactive
  use (scripts, agent automation), pipe the 6-digit code with a here-string:
  `adb pair <ip>:<port> <<< "158875"`. No interactive prompt appears.

- **mDNS discovery does not work across subnets or VPNs (Tailscale).**
  `adb mdns services` relies on multicast, which does not traverse routed
  networks. When the device is reachable only via Tailscale (e.g. a tablet
  at `100.100.10.x` paired from a ChromeOS host), mDNS returns nothing even
  when wireless debugging is active. **Fall back to a port scan** (see
  "Discovering the connection port" above): scan the ephemeral range
  (30000-60000) in parallel, then `adb connect` each open port to find the
  real ADB TLS listener. Ask the user to read the port off the device screen
  only if the scan fails — reading the screen is the last resort, not the
  first, since the port changes every session.

- **`settings put global adb_wifi_enabled 1` does not start the daemon on all
  devices.** On some OEMs (Samsung), it sets the flag but the wireless ADB
  service doesn't actually start until the UI toggle is flipped. Use
  `adb tcpip PORT` for a reliable start.

- **Samsung One UI Developer Options toggles are invisible to accessibility
  AND untappable via coordinates.** The USB debugging and Wireless debugging
  toggle rows in Samsung One UI are custom preference views that do not appear
  in the accessibility tree and do not respond to coordinate taps. The ONLY
  reliable way to toggle them programmatically is via `adb shell settings put
  global <key> <value>` (if ADB is already connected). For first-time setup
  without ADB, the user must tap them manually on the device screen.

- **`adb wifi_enabled` settings key is `adb_wifi_enabled`, not
  `adb_wireless_enabled` or `wireless_adb`.** The settings provider key is
  `adb_wifi_enabled` in the `global` namespace. Similarly, the port is
  `adb_wifi_port`. These are not documented but discoverable via
  `adb shell settings list global | grep adb`.

- **Emulators use `eth0`, not `wlan0`.** When getting the IP address for
  wireless ADB on an emulator, check `eth0` (or `eth5` on ChromeOS Crostini
  containers). Physical devices use `wlan0`.

- **ChromeOS Crostini containers have multiple eth interfaces.** `eth0` is
  typically `100.115.92.2/30` and `eth5` is `100.115.92.22/30`. Use the one
  that's reachable from your host network.

- **`adb shell settings get global adb_wifi_port` returns `null` when the
  wireless debugging service hasn't assigned a port.** This happens even when
  `adb_wifi_enabled` is `1`. The port is assigned by the adbd daemon when it
  starts listening, not by the settings provider.

- **`adb kill-server` does NOT disconnect the device.** It kills the ADB
  server process on the host. The device's adbd remains running. Run
  `adb start-server` or any `adb` command to restart it and reconnect.

- **Root access (`adb root`) only works on userdebug/eng builds.** Production
  devices return `adbd cannot run as root in production builds`. Use
  `adb unroot` to go back to non-root mode.

- **`adb -s <serial> shell` with complex quoting.** When running commands
  with pipes or redirects, wrap the entire command in double quotes:
  `adb -s <serial> shell "pm list packages -3 | grep chrome"`. Without
  quotes, the pipe runs on the host, not the device.

## Troubleshooting

### Device shows `offline`
```bash
adb kill-server
adb start-server
adb devices
# If still offline, reconnect USB cable or:
adb reconnect device
```

### Device shows `unauthorized`
- A popup should appear on the device — accept it.
- If no popup: wake the device screen, then `adb kill-server && adb start-server && adb devices`.
- If previously rejected: revoke and re-authorize via Developer Options →
  "Revoke USB debugging authorizations", then reconnect.

### `error: more than one device/emulator`
- Use `-s <serial>` or set `$ANDROID_SERIAL`.
- Run `adb devices` to see all connected serials.

### Cannot connect wirelessly
- Verify device and host are on the same network (or reachable via Tailscale).
- Verify the port: it changes each time wireless debugging is toggled. Re-read
  it after each toggle — never hardcode it.
- Try `adb disconnect` then `adb connect <ip>:<port>`.
- Firewall on the host may block the port — check iptables / ufw.
- For emulators, the IP is on eth0, not wlan0.
- **Over Tailscale / cross-subnet:** mDNS discovery won't work. Scan the
  ephemeral port range (30000-60000) in parallel for the device IP, then
  `adb connect` each open port to find the real ADB listener. Ask the user
  to read the port off the device screen only if the scan finds nothing.

### `adb tcpip` succeeds but `adb connect` fails
- Wait 2-3 seconds after `adb tcpip` for the daemon to start listening.
- Verify the port is open: `adb -s <serial> shell "netstat -tlnp | grep PORT"`.
- The USB connection may have dropped — reconnect USB, then retry.

## Reference

- `adb help` — full command reference.
- Online docs: https://android.googlesource.com/platform/packages/modules/adb/+/refs/heads/main/docs/user/adb.1.md
- `adb shell settings --help` — settings provider reference.
- `adb shell pm --help` — package manager reference.
- `adb shell input --help` — input event reference.
