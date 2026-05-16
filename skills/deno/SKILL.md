---
name: deno
description: >
  Use this skill when running, testing, or managing JavaScript/TypeScript
  projects with `deno`. Triggers on requests like "run a deno script",
  "install deno deps", "run deno tests", "deno fmt", "deno lint", or any
  Deno runtime task.
---

# deno

Run and manage JavaScript/TypeScript with the Deno runtime.

## Orientation

You must run the following commands before proceeding:

```bash
which -a deno
which deno
deno --version
deno --help
```

## Workflow

1. Confirm the tool is present: `deno --version`
2. Review available subcommands: `deno --help`
3. Run a script: `deno run <file.ts>`
4. Run tests: `deno test`
5. Format code: `deno fmt`
6. Lint: `deno lint`
7. Install dependencies: `deno install`

## Gotchas

- `deno --version` prints deno, v8, and TypeScript versions — useful context.
- Each subcommand has its own help: `deno run --help`, `deno test --help`, etc.
- Deno requires explicit permission flags (`--allow-net`, `--allow-read`, etc.) by default.

## Reference

- No `man deno` available; use `deno --help` and `deno help <subcommand>` as the primary reference.
