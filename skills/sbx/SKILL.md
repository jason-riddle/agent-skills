---
name: sbx
description: >
  Use this skill when creating, running, managing, or interacting with Docker
  Sandboxes using the `sbx` CLI. Triggers on requests like "run opencode in a
  sandbox", "create a sandbox", "list sandboxes", "exec a command in a sandbox",
  "copy files to a sandbox", "manage sandbox secrets", "publish a sandbox port",
  "manage sandbox policies", "save a sandbox template", "create a kit", or any
  Docker Sandboxes task.
---

# sbx

Create and manage isolated Docker Sandbox environments for AI agents using the `sbx` CLI.

## Orientation

Run the following commands before proceeding:

```bash
which -a sbx
which sbx
sbx version
sbx --help
```

## Workflow

1. Confirm the tool is present: `sbx version`
2. Review subcommands: `sbx --help`
3. Run opencode in a sandbox: `sbx run opencode [PATH...]`
4. List sandboxes: `sbx ls`
5. Execute a command inside a sandbox: `sbx exec -it <sandbox> bash`
6. Copy files to/from a sandbox: `sbx cp ./file my-sandbox:/home/user/`
7. Stop a sandbox: `sbx stop <sandbox>`
8. Remove a sandbox: `sbx rm <sandbox>`

## Common Workflows

### Run opencode in a sandbox

```bash
# Run opencode in the current directory
sbx run opencode

# Run with additional read-only workspace
sbx run opencode . /path/to/docs:ro

# Run on a specific git branch (isolated worktree)
sbx run opencode --branch feature-branch
sbx run opencode --branch auto   # auto-generate branch name

# Create without attaching (attach later with sbx run <sandbox-name>)
sbx create opencode .
sbx create --name my-project opencode /path/to/project

# Run with a kit applied at creation
sbx run opencode --kit ./my-kit/
sbx run opencode --kit ./kit1/ --kit ./kit2/   # stack multiple kits
```

Available agents: `claude`, `codex`, `copilot`, `cursor`, `docker-agent`, `droid`, `gemini`, `kiro`, `opencode`, `shell`

### Pass opencode options

Pass opencode CLI options after `--`:

```bash
# Resume an existing session in a named sandbox
sbx run <sandbox-name> -- -s <session-id>

# Pass arbitrary opencode flags
sbx run opencode --name my-sandbox -- <opencode-options>
```

### Exec into a running sandbox

```bash
# Interactive shell
sbx exec -it my-sandbox bash

# Run a single command
sbx exec my-sandbox ls /home/user

# Run as root
sbx exec -u root my-sandbox apt-get update

# Wrap in bash -c to source sandbox environment (e.g. for env vars)
sbx exec my-sandbox bash -c "echo $MY_VAR"
```

### Copy files

```bash
# Host → sandbox
sbx cp ./config.json my-sandbox:/home/user/

# Sandbox → host
sbx cp my-sandbox:/home/user/output.log ./

# Copy a directory
sbx cp ./src/ my-sandbox:/home/user/src
```

### Manage ports

```bash
# List published ports
sbx ports my-sandbox

# Publish sandbox port 8080 to an ephemeral host port
sbx ports my-sandbox --publish 8080

# Publish with a specific host port
sbx ports my-sandbox --publish 3000:8080

# Unpublish
sbx ports my-sandbox --unpublish 3000:8080
```

### Manage policies

Network access is deny-by-default. Use `sbx policy` to open specific domains.

```bash
# List current policies
sbx policy ls

# Allow domains globally (apply to all sandboxes)
sbx policy allow network -g "*.npmjs.org,*.pypi.org,files.pythonhosted.org"

# Allow all outbound traffic (permissive)
sbx policy allow network -g "**"

# Allow SSH to a specific IP (hostname-based rules don't work for non-HTTP)
sbx policy allow network -g "10.1.2.3:22"

# Deny a domain
sbx policy deny <rule>

# View policy decision logs (shows which requests were allowed/blocked)
sbx policy log

# Reset policies to defaults
sbx policy reset

# Set the default network policy
sbx policy set-default <policy>
```

### Save and reuse templates

```bash
# Save a running sandbox as a reusable template
sbx template save my-sandbox my-template:v1

# List templates
sbx template ls

# Run a new sandbox from a template
sbx run -t my-template:v1 opencode

# Remove a template
sbx template rm my-template:v1

# Export template to tar (for sharing or moving to another machine)
sbx template save my-sandbox my-template:v1 --output my-template.tar

# Import a tar on another machine
sbx template load my-template.tar

# Load a locally-built Docker image (bypasses registry pull)
docker image save my-org/my-template:v1 -o my-template.tar
sbx template load my-template.tar
sbx run --template my-org/my-template:v1 opencode
```

### Manage kits

Kits are declarative YAML artifacts (experimental) that extend a sandbox with tools, credentials, network rules, env vars, files, and startup commands.

```bash
# Validate a kit directory
sbx kit validate ./my-kit

# Inspect a kit
sbx kit inspect ./my-kit
sbx kit inspect ./my-kit --json

# Pack a directory as a ZIP
sbx kit pack ./my-kit -o my-kit.zip

# Add a kit to a running sandbox (re-runs install commands and re-copies files)
sbx kit add my-sandbox ./my-kit

# Push to an OCI registry
sbx kit push ./my-kit ghcr.io/myorg/my-kit:1.0

# Pull from a registry as a ZIP
sbx kit pull ghcr.io/myorg/my-kit:1.0
```

Kit sources supported by `--kit`:
- Local directory: `--kit ./my-kit/`
- ZIP file: `--kit ./my-kit.zip`
- Git repo: `--kit "git+https://github.com/org/repo.git#ref=v1.0&dir=my-kit"`
- OCI registry: `--kit ghcr.io/myorg/my-kit:1.0`

## Secrets

Secrets are stored per service name and injected by the proxy at the API level — never exposed directly to the agent.

Available services: `anthropic`, `aws`, `cursor`, `droid`, `github`, `google`, `groq`, `mistral`, `nebius`, `openai`, `xai`

```bash
# List all stored secrets
sbx secret ls

# Set a global secret (interactive prompt)
sbx secret set -g openai

# Set a global secret non-interactively from env var
echo "$OPENAI_API_KEY" | sbx secret set -g openai

# Set a secret scoped to one sandbox
sbx secret set my-sandbox anthropic

# OAuth flow (openai/global only)
sbx secret set -g openai --oauth

# Remove a secret
sbx secret rm openai
```

For secrets not supported by `sbx secret` (e.g. `BRAVE_API_KEY`), write to `/etc/sandbox-persistent.sh` inside the sandbox — it is sourced on every shell login:

```bash
sbx exec -d my-sandbox bash -c "echo 'export BRAVE_API_KEY=your_key' >> /etc/sandbox-persistent.sh"
```

## Custom Templates (Dockerfile)

Extend a base image to pre-bake tools and avoid reinstalling on every sandbox start.

Available base images (`docker/sandbox-templates:<variant>`):

| Variant               | Agent      |
|-----------------------|------------|
| `opencode`            | OpenCode   |
| `claude-code`         | Claude Code |
| `claude-code-minimal` | Claude Code (minimal) |
| `codex`               | OpenAI Codex |
| `shell`               | No agent (manual setup) |

Each variant also has a `-docker` version (e.g. `opencode-docker`) that includes a full Docker Engine inside the sandbox. The `-docker` variants are used by default when you run `sbx run opencode`.

```dockerfile
# Extend opencode base image
FROM docker/sandbox-templates:opencode
USER root
RUN apt-get update && apt-get install -y jq ripgrep
USER agent
# Install additional tools here as needed.
```

```bash
# Build and push
docker build -t my-org/my-template:v1 --push .

# Run with custom template
sbx run --template docker.io/my-org/my-template:v1 opencode
```

## Kit spec.yaml structure

A minimal mixin kit:

```yaml
schemaVersion: "1"
kind: mixin         # or "agent" to define a full agent
name: my-kit
displayName: My Kit
description: What this kit does

network:
  allowedDomains:
    - api.example.com
    - "*.cdn.example.com"
  deniedDomains:
    - telemetry.example.com

commands:
  install:
    - command: "apt-get update && apt-get install -y jq"
      user: "0"           # 0 = root, 1000 = agent
      description: Install jq
  startup:
    - command: ["sh", "-c", "my-daemon &"]
      background: true
  initFiles:
    - path: /home/agent/.my-tool/config.json
      content: '{"workspace": "${WORKDIR}"}'
      onlyIfMissing: true

environment:
  variables:
    MY_TOOL_MODE: production

files/          # optional static files tree
  home/         # → /home/agent/
  workspace/    # → primary workspace path
```

## State and Config Locations

On Linux, sbx uses two directories:

| Path | Purpose |
|------|---------|
| `~/.local/state/sandboxes/sandboxes/` | Daemon state, containerd data, runtime metadata |
| `~/.cache/sandboxes/sandboxes/` | Policy database and cache |

`~/.config/sandboxes/` is **never created** — it appears unused in current versions.

### Key paths under `~/.local/state/sandboxes/sandboxes/sandboxd/`

| Path | Purpose |
|------|---------|
| `daemon.log` | Daemon log (first place to check on failure) |
| `sandboxd.pid` | Daemon PID file |
| `sandboxd.sock` | Daemon Unix socket |
| `docker.sock` | Docker socket |
| `containerd/` | Embedded containerd root and runtime state |
| `runtimes/` | Per-sandbox runtime metadata (JSON files) |
| `runtimes/proxies/` | Per-sandbox proxy state |

### Network policies are stored in `governor.db`

`~/.cache/sandboxes/sandboxes/policykit/governor.db` is a SQLite database containing network policies. Tables: `local_policies`, `remote_policies`, `metadata`, `version`.

```bash
# Inspect policies via CLI
sbx policy ls

# Or directly with sqlite3
sqlite3 ~/.cache/sandboxes/sandboxes/policykit/governor.db "SELECT * FROM local_policies;"
```

### Secrets storage location is unknown

`sbx secret ls` confirms secrets are stored somewhere, but the raw values were not found in any file under `~/.local/state/sandboxes/` or `~/.cache/sandboxes/`. The storage backend is not yet determined.

```bash
# Inspect secrets via CLI
sbx secret ls
```

Policies are stored as JSON blobs in the `local_policies` table under the key `local-policy`.

## Debugging & Troubleshooting

### Check overall health first

```bash
sbx diagnose

# Machine-readable output
sbx diagnose --output json

# Generate a snippet for a GitHub issue
sbx diagnose --output github-issue

# Upload a diagnostics bundle to Docker support (prints a diagnostics ID)
sbx diagnose --upload
```

### Daemon status and control

```bash
# Check daemon status without trying to start it
sbx daemon status

# Start the daemon explicitly
sbx daemon start

# Stop the daemon
sbx daemon stop
```

### Read the daemon log

```bash
cat ~/.local/state/sandboxes/sandboxes/sandboxd/daemon.log

# Follow live while daemon starts
tail -f ~/.local/state/sandboxes/sandboxes/sandboxd/daemon.log
```

The log path is always printed in the error output when the daemon fails to start.

### Enable debug logging

```bash
sbx -D ls
sbx -D run opencode
sbx -D daemon start
```

### Agent can't install packages or reach an API

The sandbox network is deny-by-default. Check what's being blocked and add allow rules:

```bash
sbx policy log
sbx policy allow network -g "*.npmjs.org,*.pypi.org"
```

### Daemon fails to start (containerd error)

`failed to get "io.containerd.transfer.v1" plugin` means Docker/containerd is not running or not installed:

1. Ensure Docker Desktop (or Docker Engine) is installed and running.
2. Re-run `sbx daemon start` and check `sbx diagnose`.
3. If Docker is running but the error persists, check for a version mismatch in the daemon log.

### Daemon fails to start: `io.containerd.transfer.v1` plugin not found (Docker is running)

If `sbx daemon start` fails with:

```
ERROR: failed to start backend in-process: start backend: creating containerd server:
load required plugin io.containerd.server.v1.docker: failed to create HTTP mux:
failed to get ConnectRPC plugins: failed to create containerd client:
failed to get "io.containerd.transfer.v1" plugin: no plugins registered for
io.containerd.transfer.v1: plugin: not found
```

**and Docker is confirmed running** (`docker info` works, `systemctl is-active docker` = active), the real cause is usually a broken `mkfs.erofs` binary inside the `docker-sbx` package.

**Diagnose the actual root cause:**

```bash
# 1. Check the daemon log for the real failure
cat ~/.local/state/sandboxes/sandboxes/sandboxd/daemon.log | grep -i "transfer\|erofs"
```

Look for this pattern — it is the true root cause:

```json
{"msg":"skip loading plugin","id":"io.containerd.transfer.v1.local",
 "error":"failed to get instance for diff plugin \"erofs\":
          failed to check mkfs.erofs availability:
          failed to run mkfs.erofs --help: exit status 1: skip plugin"}
```

```bash
# 2. Test the bundled mkfs.erofs directly
/usr/libexec/mkfs.erofs --help
```

If you see:

```
/usr/libexec/mkfs.erofs: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.38' not found
```

then the `docker-sbx` package was built for Ubuntu 24.04 (Noble, glibc 2.38) but your system has an older glibc (e.g., Debian 12 Bookworm ships glibc 2.36).

```bash
# 3. Confirm your glibc version
ldd --version 2>&1 | head -1
```

**Fix — replace bundled mkfs.erofs with a Nix-built version:**

```bash
# Install erofs-utils via Nix (uses Nix's own glibc, no mismatch)
nix profile install nixpkgs#erofs-utils

# Verify it works
mkfs.erofs --help   # should print usage, not a glibc error

# Verify it supports --tar (required by sbx's erofs differ)
mkfs.erofs --help | grep -i tar

# Replace the broken bundled binary with a symlink to the Nix version
sudo mv /usr/libexec/mkfs.erofs /usr/libexec/mkfs.erofs.bak
sudo ln -s $(which mkfs.erofs) /usr/libexec/mkfs.erofs

# Verify the symlink works
/usr/libexec/mkfs.erofs --version

# Start the daemon — it should now succeed
sbx daemon start &
sleep 5
sbx version   # Server Version should now show a version, not "Unavailable"
sbx ls
```

**Why this happens:**

The `docker-sbx` `.deb` package is published targeting Ubuntu 24.04 (Noble). Its bundled
`/usr/libexec/mkfs.erofs` is compiled against glibc 2.38. On Debian 12 (Bookworm) or any
system with glibc < 2.38 (including ChromeOS Linux containers, which use a Debian Bookworm
base), the binary exits with status 1 immediately. The sbx daemon's embedded containerd
sees `mkfs.erofs --help` fail, skips the `io.containerd.transfer.v1` plugin entirely, and
then cascades into a total startup failure. The error message names `io.containerd.transfer.v1`
rather than `mkfs.erofs`, making the true cause non-obvious.

**Affected environments:**
- ChromeOS Linux (Crostini) containers — Debian Bookworm base + ChromeOS kernel
- Debian 12 (Bookworm) hosts
- Any system with glibc < 2.38 that installs the Ubuntu 24.04 `docker-sbx` package

### Stale Git worktree after removing a sandbox

```bash
git worktree remove .sbx/<sandbox-name>-worktrees/<branch-name>
git branch -D <branch-name>
```

### Clock drift after sleep/wake

If the sandbox VM clock falls behind after laptop sleep (causes TLS errors, bad timestamps):

```bash
sbx stop <sandbox-name>
sbx run <sandbox-name>
```

### Database version mismatch after downgrade

```bash
sbx reset --preserve-secrets
```

### Reset everything

```bash
# Remove all sandboxes and clean up state (destructive)
sbx reset

# Nuclear option — remove all state directories (Linux)
rm -rf ~/.local/state/sandboxes/
rm -rf ~/.cache/sandboxes/
rm -rf ~/.config/sandboxes/   # may not exist; safe to include
```

### Re-authenticate

```bash
sbx login
sbx logout
```

## Gotchas

- Kits from untrusted sources can execute arbitrary commands at sandbox creation and startup. Review `spec.yaml` contents before applying any kit from a public Git repo or OCI registry.
- `sbx reset` and the nuclear `rm -rf` cleanup commands are host-destructive and cannot be undone. Use `--preserve-secrets` to retain credentials across a reset.
- `sbx version` prints client and server versions. "Server Version: Unavailable" means the daemon is not running — use `sbx daemon start` or `sbx diagnose`.
- Most commands (`ls`, `exec`, `cp`, `ports`, `policy`, `template`) require the daemon. `sbx secret ls/set/rm` and `sbx version` work without it.
- The daemon requires Docker/containerd. Check `~/.local/state/sandboxes/sandboxes/sandboxd/daemon.log` when it fails.
- `sbx daemon start` is a hidden command (not shown in `sbx --help`) but is fully supported.
- `--kit` only applies at sandbox creation. To add a kit to a running sandbox use `sbx kit add`.
- `sbx cp` requires exactly one side to be a sandbox path (`SANDBOX:PATH`); copying between two sandboxes is not supported.
- Port spec format: `[[HOST_IP:]HOST_PORT:]SANDBOX_PORT[/PROTOCOL]`. If `HOST_PORT` is omitted, an ephemeral port is allocated.
- Sandboxes do not pick up user-level agent config from the host (e.g. `~/.claude`, `~/.opencode`). Copy what's needed into the project directory before starting.
- Agent config files (e.g. `/home/agent/.claude/settings.json`) do not persist in saved templates — they are recreated on each sandbox start.
- `sbx reset` is destructive. Use `--preserve-secrets` to keep stored secrets across a reset.
- Non-HTTP connections (SSH, etc.) require IP-based policy rules — hostname-based rules don't work for non-HTTP.
- `sbx` does not automatically resolve the `docker.io` domain in image references — use the full prefix: `docker.io/my-org/my-template:v1`.
- Private templates and kits are only supported on Docker Hub. Other registries (GHCR, ECR, etc.) are pulled anonymously.
- Set `SBX_NO_TELEMETRY=1` to opt out of CLI usage analytics.
- Startup commands in kits must be idempotent — they run on every sandbox start.
- Install commands in kits run once at creation only; `sbx kit add` re-runs them when applying to a running sandbox.

## Reference

- No `man sbx` available; use `sbx --help` and `sbx <subcommand> --help` as the primary reference.
- `sbx diagnose` — check for common installation issues.
- Report issues: https://github.com/docker/sbx-releases/issues
