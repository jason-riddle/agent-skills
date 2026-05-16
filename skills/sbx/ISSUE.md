# sbx daemon fails to start on Debian 12 (Bookworm) / ChromeOS Linux: `io.containerd.transfer.v1` plugin not found

## Summary

`sbx daemon start` fails with a misleading error about a missing `io.containerd.transfer.v1`
containerd plugin — even when Docker is fully operational. The real cause is that the bundled
`/usr/libexec/mkfs.erofs` binary in the `docker-sbx` Ubuntu 24.04 package requires glibc 2.38,
but Debian 12 (Bookworm) ships glibc 2.36. The binary exits immediately with a glibc symbol
error, causing the erofs differ plugin to be skipped, which cascades into the transfer plugin
never registering, which causes the entire daemon to fail.

## Environment

| Field | Value |
|---|---|
| `sbx` version | `v0.29.0` (package `0.29.0-1~ubuntu.24.04~noble`) |
| OS | Debian GNU/Linux 12 (Bookworm) |
| Kernel | `6.6.99-09128-g14e87a8a9b71` (ChromeOS / Crostini container) |
| glibc | `2.36-9+deb12u9` |
| Docker Server | `29.4.3` |
| Architecture | `amd64` |
| Install method | `.deb` package (`docker-sbx_0.29.0-1~ubuntu.24.04~noble_amd64.deb`) |

## Steps to Reproduce

1. Install `docker-sbx` on a Debian 12 (Bookworm) host or ChromeOS Linux (Crostini) container
   using the Ubuntu 24.04 `.deb` package.
2. Confirm Docker is running: `docker info` succeeds, `systemctl is-active docker` = `active`.
3. Run `sbx daemon start`.

## Observed Error

```
$ sbx daemon start
Starting daemon at /home/jason/.local/state/sandboxes/sandboxes/sandboxd/sandboxd.sock (Ctrl+C to stop)...
ERROR: failed to start backend in-process: start backend: creating containerd server:
load required plugin io.containerd.server.v1.docker: failed to create HTTP mux:
failed to get ConnectRPC plugins: failed to create containerd client:
failed to get "io.containerd.transfer.v1" plugin: no plugins registered for
io.containerd.transfer.v1: plugin: not found
```

`sbx version` shows the daemon as unavailable even though Docker is healthy:

```
$ sbx version
Client Version:  v0.29.0 7055fecde6b84aeb963d1680879e5620af15c119
Server Version:  Unavailable (daemon not running — use 'sbx daemon start')
```

`sbx diagnose` confirms Docker/storage are fine but the daemon socket never appears:

```
  Installation
  ✓ CLI binary — found
      /usr/bin/sbx
  ✗ Daemon — not reachable
      Get "http://localhost/daemon/health": dial unix ...sandboxd.sock: connect: no such file or directory
      → Run: sbx daemon start

  Storage
  ✓ Storage directories — all 1 paths present
  ✓ Directory permissions — all writable
```

## Root Cause

The error message `io.containerd.transfer.v1` plugin not found is a **symptom**, not the
root cause. The actual failure chain, visible in the daemon log, is:

**Step 1 — `mkfs.erofs` fails due to a glibc mismatch:**

```bash
$ /usr/libexec/mkfs.erofs --help
/usr/libexec/mkfs.erofs: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.38' not found
(required by /usr/libexec/mkfs.erofs)
```

The `docker-sbx` package is published for Ubuntu 24.04 Noble (glibc 2.38). The bundled
`/usr/libexec/mkfs.erofs` is compiled against glibc 2.38 symbols. Debian 12 Bookworm ships
glibc 2.36 — the required symbol is absent and the binary immediately exits with status 1.

**Step 2 — The daemon log shows the cascade (from `~/.local/state/sandboxes/sandboxes/sandboxd/daemon.log`):**

```json
{"level":"INFO","msg":"loading plugin","id":"io.containerd.transfer.v1.local","type":"io.containerd.transfer.v1"}
{"level":"INFO","msg":"skip loading plugin","id":"io.containerd.transfer.v1.local","type":"io.containerd.transfer.v1",
 "error":"failed to get instance for diff plugin \"erofs\": failed to check mkfs.erofs availability: failed to run mkfs.erofs --help: exit status 1: skip plugin"}
{"level":"WARN","msg":"failed to load plugin","id":"io.containerd.grpc.v1.transfer","type":"io.containerd.grpc.v1",
 "error":"no plugins registered for io.containerd.transfer.v1: plugin: not found"}
{"level":"WARN","msg":"failed to load plugin","id":"com.docker.containerd-client.v1.local",
 "error":"failed to create containerd client: failed to get \"io.containerd.transfer.v1\" plugin: no plugins registered for io.containerd.transfer.v1: plugin: not found"}
```

Cascade:
1. `mkfs.erofs --help` exits 1 (glibc 2.38 symbol missing on glibc 2.36 system)
2. The erofs differ plugin check fails → `io.containerd.transfer.v1.local` is **skipped**
3. No `io.containerd.transfer.v1` plugin is registered
4. Every plugin that depends on it (containerd client, image service, container service, etc.) fails to load
5. `io.containerd.server.v1.docker` fails → daemon exits

**Why Docker being running doesn't help:**

`sbx` embeds its own containerd instance (stored under `~/.local/state/sandboxes/`). It does
not use the system Docker socket. The embedded containerd fails to initialize because of the
bad `mkfs.erofs` binary that ships inside the `docker-sbx` package itself.

## Fix

Replace the broken bundled `mkfs.erofs` with a working one. Using Nix avoids the glibc
dependency entirely since Nix packages carry their own linked libraries.

```bash
# 1. Install erofs-utils via Nix
nix profile install nixpkgs#erofs-utils

# 2. Verify it works
$ mkfs.erofs --help
Usage: mkfs.erofs [OPTIONS] FILE SOURCE(s)
Generate EROFS image (FILE) from SOURCE(s).
...

# Verify --tar support is present (required by sbx)
$ mkfs.erofs --help | grep -i tar
 --tar=X                generate a full or index-only image from a tarball(-ish) source

# 3. Replace the broken bundled binary with a symlink to the Nix version
sudo mv /usr/libexec/mkfs.erofs /usr/libexec/mkfs.erofs.bak
sudo ln -s $(which mkfs.erofs) /usr/libexec/mkfs.erofs

# 4. Confirm the symlink resolves correctly
$ /usr/libexec/mkfs.erofs --version
mkfs.erofs (erofs-utils) 1.9
available compressors: lz4, lz4hc, lzma, deflate, libdeflate, zstd

# 5. Start the daemon
$ sbx daemon start &
Starting daemon at /home/jason/.local/state/sandboxes/sandboxes/sandboxd/sandboxd.sock ...

# 6. Confirm it is working
$ sbx version
Client Version:  v0.29.0 7055fecde6b84aeb963d1680879e5620af15c119
Server Version:  v0.29.0 7055fecde6b84aeb963d1680879e5620af15c119

$ sbx ls
No sandboxes found.
Launch one: sbx run claude
```

## Expected Behavior

Either:
- The `docker-sbx` package should include a Debian Bookworm-compatible build of `mkfs.erofs`
  (compiled against glibc 2.36), or
- The error message should surface the actual failure (`mkfs.erofs: GLIBC_2.38 not found`)
  rather than the downstream symptom (`io.containerd.transfer.v1: plugin not found`)

## Workaround

Install `erofs-utils` via Nix and symlink `/usr/libexec/mkfs.erofs` as described above.
The fix survives reboots as long as the Nix profile remains installed.

## Additional Notes

- This was reproduced on a **ChromeOS Linux (Crostini)** container, which uses a Debian 12
  Bookworm userland on top of a ChromeOS kernel (`6.6.99` Chromium OS build).
- The `docker-sbx` package version string `0.29.0-1~ubuntu.24.04~noble` makes the Ubuntu 24.04
  targeting explicit, but the package is distributed without a Debian variant.
- Installing system `containerd` via Nix (`nix profile install nixpkgs#containerd`) does **not**
  fix the issue — `sbx` ignores the system containerd socket and embeds its own. The only
  effective fix is repairing the `mkfs.erofs` binary that `sbx`'s embedded containerd calls.
