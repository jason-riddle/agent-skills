---
name: lmstudio-lm-link
description: >
  Use this skill when working with LM Studio's LM Link feature — connecting
  devices, loading remote models, checking link status, debugging connectivity,
  or calling the local API backed by a remote machine. Triggers on requests
  like "load a model on the remote machine", "check LM Link status", "use lms
  to run a remote model", "why isn't LM Link working", "call a model via
  lmstudio", or any task involving lmstudio's cross-device inference via
  `lms link` or `lms load`.
---

# lmstudio-lm-link

Run inference on a remote machine and access it via the standard
OpenAI-compatible API at `localhost:1234` on the local machine. LM Link
handles the encrypted relay — no direct network connectivity, open ports, or
Tailscale ACL changes are needed.

## How it works

LM Link uses LM Studio's own private Tailscale mesh VPN, entirely separate
from any personal Tailscale tailnet. The `lmlink-connector` process on each
machine connects outbound to LM Studio's cloud relay. No inbound ports are
opened and no changes to any Tailscale ACL policy are required.

```
curl → localhost:1234 → llmster → lmlink-connector → LM Studio relay → remote lmlink-connector → remote inference engine
```

The local machine acts as a proxy client — all inference happens on the
remote peer.

## Orientation

```bash
lms link status --json     # peer connectivity and loaded models
lms ps                     # confirm DEVICE column shows the remote peer
lms ls                     # all models available across linked devices
lms server status          # confirm localhost:1234 is running
```

## Workflow

### Check LM Link is connected

```bash
lms link status --json
# Expect: "status":"online", peers[0].status:"connected"
```

### Start the local server (if not running)

```bash
lms server start
lms server status
```

The server must be running for `localhost:1234` to accept API calls. It
proxies requests to the remote peer via LM Link — it does not run local
inference.

### List available models

```bash
lms ls
# DEVICE column shows which machine each model is stored on
```

### Load a model on the remote peer

```bash
lms load "<model-key>" -y    # -y auto-selects the preferred device
lms ps                        # confirm DEVICE = remote peer name
```

### Call the API

```bash
curl http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<model-key>",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

Point any OpenAI-compatible tool to:
- `base_url`: `http://localhost:1234/v1`
- `model`: identifier from `lms ps`

### Unload a model

```bash
lms unload "<model-key>"
```

### Set a preferred remote device (persistent)

```bash
# Get the device identifier from lms link status --json
lms link set-preferred-device <deviceIdentifier>
```

## Proving inference is remote (not local)

`lms ps` is the authoritative proof — the `DEVICE` column shows where the
model is actually loaded:

```
IDENTIFIER    MODEL         DEVICE
<model-key>   <model-key>   <remote-device-name>   ← remote
```

If `DEVICE` shows `Local`, the model is running on the local machine.

## Gotchas

- **LM Link ≠ your personal Tailscale.** LM Link has its own private mesh.
  Do not add port rules to any Tailscale ACL policy — they have no effect on
  LM Link. A remote peer being unreachable via ping or direct SSH does not
  affect LM Link connectivity.

- **The local server must be running** for `localhost:1234` to work. Check
  with `lms server status`. Start with `lms server start`.

- **`loadedModels: []` in link status is normal** when no model has been
  explicitly loaded. Run `lms load <model> -y` to load one.

- **`lms ps` with no output** means no model is loaded on any device. Load
  one before making API calls, or enable just-in-time loading in LM Studio
  settings.

- **`lms load` without `-y`** may prompt interactively to choose a device.
  Use `-y` to auto-select the preferred device in scripts.

- **The remote machine must have LM Studio open** (or `llmster` running) for
  LM Link to work. If `lms link status --json` shows `status: "offline"` or
  no peers, check that LM Studio is running on the remote machine.

## Reference

```bash
lms --help
lms link --help
lms load --help
lms server --help
lms ps
lms ls
```

Server logs: `~/.lmstudio/server-logs/`
LM Link config: `~/.lmstudio/.internal/lm-link-config.json`
LM Link account cache: `~/.lmstudio/.internal/lm-link-account-status-cache.json`
