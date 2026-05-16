---
name: opencode
description: >
  Use this skill when working with the OpenCode AI coding agent CLI. Triggers
  on requests like "run opencode", "start opencode", "configure opencode",
  "use opencode to do X", or any task involving the `opencode` CLI tool.
---

# opencode

Run and configure the OpenCode AI coding agent via the `opencode` CLI.

## Orientation

You must run the following commands before proceeding:

```bash
which -a opencode
which opencode
opencode --version
opencode --help
```

## Workflow

1. Confirm the tool is present: `opencode --version`
2. Review flags and subcommands: `opencode --help`
3. Start an interactive session: `opencode`
4. Run a one-shot prompt: `opencode -p "your prompt here"`

## Gotchas

- `opencode --version` prints the version number.
- Configuration lives in the project or home directory; check `opencode --help` for config file location.

## Reference

- No `man opencode` available; use `opencode --help` as the primary reference.
