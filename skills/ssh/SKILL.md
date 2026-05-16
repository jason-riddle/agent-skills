---
name: ssh
description: >
  Use this skill when connecting to remote hosts, managing SSH keys, tunneling,
  or configuring SSH with `ssh`, `ssh-keygen`, `ssh-copy-id`, or `sshpass`.
  Triggers on requests like "connect via SSH", "generate an SSH key", "copy my
  SSH key to a server", "set up SSH tunneling", "copy files with scp", "use a
  password to copy a key", or any SSH-related task including debugging
  connectivity issues.
---

# ssh

Connect to remote systems, manage SSH keys, and debug SSH connectivity.

## Orientation

Run the following before proceeding:

```bash
which -a ssh
which ssh
ssh -V
```

## Key generation

Generate a new ed25519 key (preferred):

```bash
ssh-keygen -t ed25519 -C "user@host" -f ~/.ssh/id_ed25519 -N ""
```

- `-C` sets the comment (e.g. `jason@penguin`)
- `-f` sets the output file path
- `-N ""` sets an empty passphrase (omit to be prompted)

To overwrite an existing key without prompting, add `-y` or delete the old key first.

## Copying a key to a remote host

### With key-based auth already working

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@host
ssh-copy-id -i ~/.ssh/id_ed25519.pub -p 2222 user@host   # non-default port
```

### With password auth (using sshpass)

When the old key is lost or key auth is not yet set up, use `sshpass` to supply
the password non-interactively:

```bash
sshpass -p 'PASSWORD' ssh-copy-id -i ~/.ssh/id_ed25519.pub \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=8 \
  -p 2222 user@host
```

- `-o StrictHostKeyChecking=no` avoids host-key prompts blocking the command
- `-o ConnectTimeout=8` prevents hanging on unreachable hosts
- Set a bash timeout to avoid indefinite hangs: use `timeout 8000` (ms) in the tool

Install sshpass if missing:

```bash
# Debian/Ubuntu
sudo apt-get install sshpass

# macOS (Homebrew)
brew install hudochenkov/sshpass/sshpass
```

## Connecting

```bash
ssh user@host
ssh -p 2222 user@host                    # non-default port
ssh -i ~/.ssh/id_ed25519 user@host       # explicit key
ssh -o ConnectTimeout=8 user@host        # timeout
```

## Tunneling

```bash
ssh -L localport:remotehost:remoteport user@host    # local forward
ssh -R remoteport:localhost:localport user@host     # remote forward
ssh -D 1080 user@host                               # SOCKS proxy
```

## Debugging connectivity

When SSH hangs or refuses connection, work through these checks in order:

### 1. Check DNS / hostname resolution

```bash
getent hosts <hostname>
```

### 2. Check network reachability (ping)

```bash
ping -c 2 -W 3 <hostname>
```

Note: ping uses ICMP — a host may be up but have ICMP blocked. Ping failure
does not definitively mean the host is down.

### 3. Check if the SSH port is open (TCP)

```bash
timeout 8 bash -c 'echo > /dev/tcp/<host>/<port>' && echo "Port open" || echo "Port closed/unreachable"
```

Or with nc:

```bash
nc -zv -w 5 <host> 2222
```

### 4. Run SSH in verbose mode

```bash
ssh -vvv -p 2222 user@host
```

Verbose output shows exactly where the handshake fails (DNS, TCP, auth, etc.).

### 5. Check Tailscale (if applicable)

```bash
tailscale status
```

Look for the target host — verify it shows `active` and not `offline`. A host
can appear active in Tailscale but still have its SSH port blocked by firewall
rules.

## Gotchas

- `ssh` uses `-V` for version (uppercase), not `--version`.
- There is no `ssh --help`; use the man page as the primary reference.
- `sshpass` passes passwords in plaintext on the command line — visible in
  process lists. Use only when necessary; prefer key-based auth.
- `ssh-copy-id` will hang indefinitely waiting for a password prompt if
  `sshpass` is not used and the terminal is non-interactive. Always set
  `ConnectTimeout` and use a tool-level timeout when running non-interactively.
- A host active on Tailscale (100.x.x.x) may still have port 2222 unreachable
  if the SSH service is stopped or the firewall blocks it. TCP-check the port
  directly rather than relying on ping or Tailscale status alone.
- If port 2222 is blocked, also try port 22 — some hosts run SSH on the
  standard port.

## Reference

- `man ssh` — primary flag and option reference.
- `man ssh_config` — SSH client config file options.
- `man ssh-keygen` — key generation reference.
- `man ssh-copy-id` — key copy reference.
- `man scp` — secure copy reference.
- `man sftp` — SFTP client reference.
- `man sshpass` — non-interactive password supply.
