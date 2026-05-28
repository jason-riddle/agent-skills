---
name: lmstudio-lm-link
description: >
  Use this skill when working with LM Studio's LM Link feature — connecting
  devices, loading remote models, checking link status, debugging connectivity,
  or calling the local API backed by a remote machine. Triggers on requests
  like "load a model on the Mac", "check LM Link status", "use lms to run a
  remote model", "why isn't LM Link working", "call a model via lmstudio",
  or any task involving lmstudio's cross-device inference via `lms link` or
  `lms load`.
---

# lmstudio-lm-link

Run inference on a remote machine (Mac Mini) and access it via the standard
OpenAI-compatible API at `localhost:1234` on this Chromebook. LM Link handles
the encrypted relay — no direct network connectivity, open ports, or Tailscale
ACL changes are needed.

## How it works

LM Link uses LM Studio's own private Tailscale mesh VPN (separate from your
personal tailnet). The `lmlink-connector` process on each machine connects
outbound to LM Studio's cloud relay. No inbound ports are opened and no
changes to `policy.hujson` are required.

**Architecture on this machine (chromeos-penguin):**

```
curl → localhost:1234 → llmster → lmlink-connector → LM Studio relay → Mac lmlink-connector → Mac inference engine
```

This Chromebook (Intel i3-N305, no GPU) is too weak to run models locally.
It acts purely as a proxy client — all inference happens on the Mac Mini.

## Orientation

```bash
lms link status --json     # peer connectivity, loaded models
lms ps                     # confirm DEVICE column shows Mac, not local
lms ls                     # all models available across linked devices
lms server status          # confirm localhost:1234 is running
```

## Workflow

### Check LM Link is connected

```bash
lms link status --json
# Expect: "status":"online", peers[0].status:"connected", deviceName:"Jasons-Mac-Mini.local"
```

### Start the local server (if not running)

```bash
lms server start
lms server status
```

The server must be running for `localhost:1234` to accept API calls. It does
not run local inference — it proxies requests to the Mac via LM Link.

### Load a model on the Mac

```bash
lms load "google/gemma-3-1b" -y       # -y auto-selects Mac as preferred device
lms ps                                  # confirm DEVICE = Jasons-Mac-Mini.local
```

Available models (stored on the Mac):

| Model | Size |
|---|---|
| `google/gemma-3-1b` | 772 MB |
| `google/gemma-3-4b` | 3.03 GB |
| `google/gemma-3n-e4b` | 5.86 GB |
| `google/gemma-2-9b` | 5.76 GB |
| `microsoft/phi-4-mini-reasoning` | 2.18 GB |
| `microsoft/phi-4-reasoning-plus` | 8.26 GB |
| `qwen/qwen3-4b-2507` | 2.28 GB |
| `qwen/qwen3-4b-thinking-2507` | 2.28 GB |

### Call the API

```bash
curl http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-3-1b",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

Point any OpenAI-compatible tool to:
- `base_url`: `http://localhost:1234/v1`
- `model`: identifier from `lms ps`

### Unload a model

```bash
lms unload "google/gemma-3-1b"
```

### Set the Mac as preferred device (persistent)

```bash
# Get the Mac's device identifier from lms link status --json
lms link set-preferred-device d25230e9e39b321207f044e695382f70
```

## Proving inference is on the Mac (not local)

`lms ps` is the authoritative proof — the `DEVICE` column shows where the
model is loaded:

```
IDENTIFIER           MODEL              DEVICE
google/gemma-3-1b    google/gemma-3-1b  Jasons-Mac-Mini.local   ← Mac
```

If `DEVICE` showed `Local`, it would be running on this Chromebook (which
cannot actually run models — the inference would fail or be extremely slow).

## Gotchas

- **LM Link ≠ your personal Tailscale.** LM Link has its own private mesh.
  Do not add port rules to `policy.hujson` — they have no effect on LM Link.
  The Mac's Tailscale IP (100.100.10.50) being unreachable via ping does not
  affect LM Link at all.

- **The server must be running** for `localhost:1234` to work. Check with
  `lms server status`. Start with `lms server start`.

- **`loadedModels: []` in link status is normal** when no model has been
  explicitly loaded. Run `lms load <model> -y` to load one.

- **`lms ps` with no output** means no model is loaded on any device. Load
  one before making API calls, or enable just-in-time loading in LM Studio
  settings.

- **Do not run `lms server start` expecting local inference.** The server on
  this Chromebook is a proxy only. Local model loading will either fail
  (insufficient RAM/GPU) or be uselessly slow.

- **`lms load` without `-y`** may prompt interactively to choose a device.
  Use `-y` to auto-select the preferred device (Mac) in scripts.

- **The Mac must have LM Studio open** (or `llmster` running) for LM Link to
  work. If `lms link status --json` shows `status: "offline"` or the peer
  is missing, check that LM Studio is running on the Mac.

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
