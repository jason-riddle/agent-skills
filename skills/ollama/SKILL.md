---
name: ollama
description: >
  Use this skill when running, managing, or interacting with local LLM models
  via `ollama`. Triggers on requests like "run a model with ollama", "pull
  an ollama model", "list ollama models", "start ollama server", or any
  local LLM task using Ollama.
---

# ollama

Run and manage local LLM models using `ollama`.

## Orientation

You must run the following commands before proceeding:

```bash
which -a ollama
which ollama
ollama --version
ollama --help
```

## Workflow

1. Confirm the tool is present: `ollama --version`
2. Review subcommands: `ollama --help`
3. Pull a model: `ollama pull <model>`
4. Run a model interactively: `ollama run <model>`
5. List downloaded models: `ollama list`
6. Start the server: `ollama serve`
7. Remove a model: `ollama rm <model>`

## Gotchas

- `ollama --version` may print a warning if the server is not running; that is normal.
- Each subcommand has help: `ollama pull --help`, `ollama run --help`, etc.
- The server must be running (`ollama serve`) before most API calls work.

## Reference

- No `man ollama` available; use `ollama --help` and `ollama help <subcommand>` as the primary reference.
