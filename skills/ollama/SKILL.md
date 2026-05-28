---
name: ollama
description: >
  Use this skill when running, managing, or interacting with LLM models via
  `ollama` — locally or on a remote machine. Triggers on requests like "run a
  model with ollama", "pull an ollama model", "list ollama models", "start
  ollama server", "call ollama on a remote machine", "connect to a remote
  ollama instance", "what models are available on ollama", "find a model on
  ollama.com", "inspect a model", or any LLM task using Ollama whether local
  or remote.
---

# ollama

Run and manage LLM models using `ollama`, either locally or on a remote machine
accessed directly over the network.

## Orientation

```bash
which ollama
ollama --version
ollama --help
```

## Workflow

### Local

1. Confirm the tool is present: `ollama --version`
2. Start the server if not running: `ollama serve`
3. Pull a model: `ollama pull <model>`
4. Run a model interactively: `ollama run <model>`
5. List downloaded models: `ollama list`
6. Remove a model: `ollama rm <model>`

### Remote

Ollama has no built-in remote relay (unlike LM Studio's LM Link). Access a
remote Ollama instance by pointing directly at its host and port over a secure
network (e.g. Tailscale):

```bash
# List available models on a remote instance
curl http://<remote-host>:11434/api/tags

# Run inference (non-streaming)
curl http://<remote-host>:11434/api/chat \
  -d '{"model":"<model>","messages":[{"role":"user","content":"Hello"}],"stream":false}'

# OpenAI-compatible endpoint — works with most tools
# base_url: http://<remote-host>:11434/v1
# model: <model-name>
```

Replace `<remote-host>` with the remote machine's Tailscale IP or hostname.
Port 11434 is the Ollama default.

## Discovering models on ollama.com

Browse and search at https://ollama.com/search — models are filterable by
category (e.g. vision, tools, embedding, code).

Each model has a library page at `https://ollama.com/library/<model>` listing
all available tags (sizes and quantizations).

Common tag suffixes:

| Tag | Meaning |
|---|---|
| `:latest` | Default tag — usually the recommended size |
| `:1b`, `:3b`, `:7b` | Parameter count (smaller = faster, less capable) |
| `q4_0`, `q4_k_m`, `q8_0` | Quantization level (higher = more accurate, larger) |
| `fp16` | Full precision — largest and most accurate |

If no tag is specified, `ollama pull <model>` fetches `:latest`.

### Inspect a model on ollama.com without pulling it

Use `https://ollama.com/api/show` to fetch model metadata directly from the
ollama.com library — no local Ollama install required:

```bash
# Show metadata for a model (architecture, context length, capabilities, etc.)
curl -s -X POST https://ollama.com/api/show \
  -d '{"name":"llama3.2:latest"}' | jq .

# Example output fields: details.family, details.parameter_size,
# model_info.*.context_length, capabilities (completion, vision, tools, etc.)
```

The `name` field must match a tag listed on the model's library page
(`https://ollama.com/library/<model>`). Use `:latest` if unsure of the tag.

### Query ollama.com featured models with jq

```bash
# List all featured model names
curl -s https://ollama.com/api/tags | jq '[.models[].name]'

# Show name and size (in GB), sorted smallest first
curl -s https://ollama.com/api/tags | jq '[.models[] | {name, size_gb: (.size/1e9 | . * 10 | round / 10)}] | sort_by(.size_gb)'

# Filter to models under a size threshold (e.g. under 10 GB)
curl -s https://ollama.com/api/tags | jq '[.models[] | select(.size < 10000000000) | {name, size_gb: (.size/1e9 | . * 10 | round / 10)}]'
```

Note: `https://ollama.com/api/tags` returns a curated/featured subset (~40
models), not the full library. Browse the full catalog at
`https://ollama.com/search`.

### Pull and inspect a model

```bash
# Pull a specific model and tag
ollama pull <model>:<tag>

# Show model info (architecture, context length, quantization, capabilities)
ollama show <model>:<tag>

# Show individual details
ollama show <model>:<tag> --modelfile     # Modelfile used to create it
ollama show <model>:<tag> --parameters   # Runtime parameters (temperature, stop tokens, etc.)
ollama show <model>:<tag> --template     # Prompt template
ollama show <model>:<tag> --system       # System prompt (if any)
ollama show <model>:<tag> --license      # License
ollama show <model>:<tag> --verbose      # Full detail dump

# List all locally pulled models
ollama list

# List currently running models
ollama ps
```

### Point the CLI at a remote instance

Set `OLLAMA_HOST` to run any `ollama` CLI command against a remote instance
instead of localhost:

```bash
OLLAMA_HOST=http://<remote-host>:11434 ollama list
OLLAMA_HOST=http://<remote-host>:11434 ollama show <model>
OLLAMA_HOST=http://<remote-host>:11434 ollama pull <model>
OLLAMA_HOST=http://<remote-host>:11434 ollama run <model>
```

## Gotchas

- `ollama --version` may print a warning if the server is not running; that is
  normal.
- The server must be running (`ollama serve`) before API calls work. On macOS,
  the Ollama.app also starts the server automatically.
- When accessing a remote instance, the `ollama` CLI is not required locally —
  use `curl` or any HTTP client directly against the remote API.
- ICMP (ping) may be blocked by the remote machine's firewall while TCP port
  11434 remains open. A failed ping does not mean the Ollama API is unreachable.
- For remote access over Tailscale, ensure the ACL policy grants access to port
  11434 from the source device to the remote device. Without an explicit grant,
  access may rely on implicit member-to-member rules which can be unreliable.
- `stream` defaults to `true` in the Ollama API. Pass `"stream":false` for a
  single JSON response instead of a streaming one.

## Reference

- No `man ollama` available; use `ollama --help` and `ollama help <subcommand>`.
- API docs: https://github.com/ollama/ollama/blob/main/docs/api.md
- OpenAI compatibility: https://github.com/ollama/ollama/blob/main/docs/openai.md
