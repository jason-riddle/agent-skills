---
name: hermes
description: >
  Use this skill when installing, configuring, running, or managing Hermes Agent
  — the NousResearch AI agent CLI. Triggers on requests like "install hermes",
  "run hermes", "configure hermes", "set up hermes on a server", "connect hermes
  to a messaging platform", "set the hermes model", "check hermes health", "send
  a message via hermes", or any task involving the `hermes` CLI tool. Also use
  when configuring Hermes providers (OpenRouter, Anthropic, Cloudflare AI Gateway),
  managing skills/plugins, setting up a gateway (Telegram, Discord, Slack), or
  troubleshooting Hermes errors.
---

# hermes

Install, configure, and run Hermes Agent — an AI agent CLI by NousResearch with
tool-calling, skills, messaging gateway, and MCP support.

## Orientation

Run the following commands before proceeding:

```bash
which -a hermes
which hermes
hermes version
hermes --help
```

## Installation

The preferred install method on Linux/macOS is the git installer:

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

Pass `--skip-browser` to skip Playwright/Chromium (recommended for headless servers):

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-browser
```

After install, reload the shell:

```bash
source ~/.bashrc   # or source ~/.zshrc
```

Install layout (root user):

| Path | Purpose |
|------|---------|
| `/usr/local/lib/hermes-agent/` | Source and virtualenv |
| `/usr/local/bin/hermes` | Launcher binary |
| `~/.hermes/.env` | API keys and secrets |
| `~/.hermes/config.yaml` | Non-secret config |
| `~/.hermes/SOUL.md` | Personality customization |

## Workflow

1. Confirm the tool is present: `hermes version`
2. Run the health check: `hermes doctor`
3. Configure the provider and model: `hermes model`
4. Set API keys: `hermes config set OPENROUTER_API_KEY sk-or-...`
5. Start chatting: `hermes` or `hermes --tui`
6. Run a one-shot prompt (non-interactive): `hermes -z "your prompt"`

## Configuration

Settings are split across two files:

- **Secrets** (`~/.hermes/.env`): API keys, tokens, passwords
- **Config** (`~/.hermes/config.yaml`): model, terminal backend, compression, etc.

Use `hermes config set` to write to the correct file automatically:

```bash
hermes config set model anthropic/claude-sonnet-4-5
hermes config set OPENROUTER_API_KEY sk-or-...
hermes config set terminal.backend docker
hermes config set OPENROUTER_BASE_URL https://gateway.ai.cloudflare.com/v1/<id>/<slug>/openrouter
```

View current config:

```bash
hermes config
hermes config edit   # open in $EDITOR
```

## Provider Setup

### OpenRouter (recommended)

```bash
hermes config set OPENROUTER_API_KEY sk-or-...
hermes config set model anthropic/claude-sonnet-4-5
```

Use a Cloudflare AI Gateway as the base URL (optional — for caching/observability):

```bash
hermes config set OPENROUTER_BASE_URL https://gateway.ai.cloudflare.com/v1/<account-id>/<slug>/openrouter
```

Set `OPENROUTER_BASE_URL` in `~/.hermes/.env`, not `config.yaml`. If
`hermes config set` writes it to `config.yaml`, move it manually.

Model IDs for OpenRouter are just `provider/model` — do **not** prefix with `openrouter/`:

```bash
# Correct
hermes config set model anthropic/claude-sonnet-4-5

# Wrong — results in HTTP 400 "not a valid model ID"
hermes config set model openrouter/anthropic/claude-sonnet-4-5
```

### Anthropic direct

```bash
hermes config set ANTHROPIC_API_KEY sk-ant-...
hermes config set model claude-sonnet-4-5
```

### Custom / self-hosted endpoint

```bash
hermes config set CUSTOM_BASE_URL http://localhost:11434/v1
hermes config set model my-model-name
```

## Common Workflows

### Start an interactive chat session

```bash
hermes             # classic REPL
hermes --tui       # modern TUI (modal overlays, mouse support)
```

### One-shot prompt (scripting / CI)

```bash
hermes -z "Summarize the current directory structure"
hermes chat -q "What is the current date?"
```

### Resume a previous session

```bash
hermes --continue        # resume most recent session
hermes -c                # short form
hermes sessions list     # list all sessions
hermes --resume <id>     # resume by session ID
```

### Switch models at runtime

```bash
hermes model             # interactive picker
/model                   # slash command inside a session
```

### Run diagnostics

```bash
hermes doctor            # check config, deps, auth
hermes status            # show status of all components
hermes dump              # full setup summary for debugging
```

### Update Hermes

```bash
hermes update
```

### Install and use skills

```bash
hermes skills search kubernetes
hermes skills install openai/skills/k8s
# Inside a session:
/skills
```

### Gateway (messaging platforms)

Set up Hermes as a Telegram/Discord/Slack bot:

```bash
hermes gateway setup     # interactive setup wizard
hermes gateway install   # install as a background service
hermes gateway status    # check gateway health
```

On Linux with systemd, `hermes gateway install` creates a user service
(`~/.config/systemd/user/hermes-gateway.service`) and enables linger so the
gateway survives SSH logout.

For Mattermost specifically, the required `.env` settings are:

```bash
MATTERMOST_URL=https://mattermost.example.com
MATTERMOST_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxx
MATTERMOST_ALLOWED_USERS=<mattermost-user-id>
```

Common optional Mattermost settings:

```bash
MATTERMOST_HOME_CHANNEL=<channel-id>
MATTERMOST_REPLY_MODE=thread
MATTERMOST_REQUIRE_MENTION=true
```

To find the values:

- `MATTERMOST_TOKEN`: create a Mattermost bot account and copy the token once
- `MATTERMOST_ALLOWED_USERS`: use the 26-character Mattermost user ID, not the username
- `MATTERMOST_HOME_CHANNEL`: use the channel ID, not the channel name

### MCP servers

Add to `~/.hermes/config.yaml`:

```yaml
mcp_servers:
  github:
    command: npx
    args: ["-y", "@modelcontextprotocol/server-github"]
    env:
      GITHUB_PERSONAL_ACCESS_TOKEN: "ghp_xxx"
```

### Sandboxed terminal backend

```bash
hermes config set terminal.backend docker   # isolate commands in Docker
hermes config set terminal.backend ssh      # run commands on a remote host
hermes config set terminal.backend local    # default: run commands locally
```

## Gotchas

- Model IDs when using OpenRouter must **not** include the `openrouter/` prefix.
  `openrouter/anthropic/claude-opus-4.6` will return HTTP 400. Use
  `anthropic/claude-opus-4.6` directly.
- `hermes config set OPENROUTER_BASE_URL ...` may write the value to
  `config.yaml` instead of `.env`. API keys and base URLs belong in `.env` —
  move them manually if needed.
- `hermes gateway install` accepts `HERMES_ACCEPT_HOOKS=1` as an environment
  variable for non-interactive installs; passing `--accept-hooks` after the
  subcommand can fail argument parsing.
- Hermes requires a model with at least **64,000 tokens** of context. Models
  with smaller windows are rejected at startup.
- `hermes -z` (oneshot mode) produces no banner or spinner — output is the raw
  response only. If it produces no output at all, check `hermes chat -q` for
  the error message.
- On first install the setup wizard is skipped in headless/non-TTY environments.
  Run `hermes setup` manually after install on a server.
- `hermes doctor` will warn about optional packages (telegram, discord) not
  being installed — these are only needed for gateway use.
- The compression threshold warning (`Auto-lowered this session's threshold`)
  is cosmetic. Silence it permanently by setting `compression.threshold: 0.20`
  in `config.yaml`.
- For Mattermost, Hermes needs both team membership and channel membership.
  A valid bot token is not enough if the bot has not been added to a team yet.
- Mattermost `home channel` values use the channel ID, not a name like
  `General` or `general`.
- When running as root (e.g. on a DigitalOcean droplet), config lives at
  `/root/.hermes/` not `~/.hermes/` — they are the same path, but be explicit
  when scripting.

## Reference

- No `man hermes` available; use `hermes --help` and `hermes <subcommand> --help`.
- `hermes doctor` — primary diagnostic tool.
- Docs: https://hermes-agent.nousresearch.com/docs/getting-started/quickstart
- GitHub: https://github.com/NousResearch/hermes-agent
