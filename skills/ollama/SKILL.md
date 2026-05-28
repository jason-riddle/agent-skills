---
name: ollama
description: >
  Use this skill when running, managing, or interacting with LLM models via
  `ollama` — locally or on a remote machine. Triggers on requests like "run a
  model with ollama", "pull an ollama model", "list ollama models", "start
  ollama server", "call ollama on a remote machine", "connect to a remote
  ollama instance", or any LLM task using Ollama whether local or remote.
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
