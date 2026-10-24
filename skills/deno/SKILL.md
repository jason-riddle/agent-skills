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

Apply the dependency-age and execution gates below before commands that can
fetch dependencies or run code; the examples are not a required sequence.

1. Confirm the tool is present: `deno --version`
2. Review available subcommands: `deno --help`
3. Run a script: `deno run <file.ts>`
4. Run tests: `deno test`
5. Format code: `deno fmt`
6. Lint: `deno lint`
7. Install dependencies: `deno install`

## Dependency-age and execution gates

- Never change global/user Deno or npm age settings to unblock a task.
- If a dependency is too new, stop and report the package, pinned version and
  blocking policy without installing it. Prefer waiting or an approved
  eligible version; an older task's exception is not standing authorization.
- Only with present task-specific approval, pin the reviewed version and
  scope `--minimum-dependency-age=0` to that exact invocation. Check installed
  subcommand help for support; do not substitute a persistent configuration
  change if the scoped flag is unavailable.
- An age override establishes neither package safety nor permission to use
  `-y`, `-A`, lifecycle scripts, broader filesystem/network permissions,
  OAuth, or MCP reads/writes. Review source/provenance and each effect
  independently; grant only the permissions needed for the approved task.

## Gotchas

- `deno --version` prints deno, v8, and TypeScript versions — useful context.
- Each subcommand has its own help: `deno run --help`, `deno test --help`, etc.
- Deno requires explicit permission flags (`--allow-net`, `--allow-read`, etc.) by default.

## Reference

- No `man deno` available; use `deno --help` and `deno help <subcommand>` as the primary reference.
