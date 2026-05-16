---
name: mcp-remote
description: >
  Use this skill when connecting an stdio-only MCP client to a remote MCP
  server using `mcp-remote` via `npx`. Triggers on requests like "connect to
  a remote MCP server", "add mcp-remote to Claude Desktop", "use OAuth with
  an MCP server", "configure mcp-remote", or any task bridging a local MCP
  client to a remote MCP endpoint.
---

# mcp-remote

Bridge a local stdio-only MCP client to a remote MCP server (with OAuth auth
support) using `mcp-remote` via `npx`.

## Orientation

`mcp-remote` is not a standalone installed binary — it is invoked via `npx`. You must run the following commands before proceeding:

```bash
which -a npx
which npx
npx mcp-remote --help
```

## Basic config

Add to your MCP client config (e.g., `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "remote-example": {
      "command": "npx",
      "args": ["mcp-remote", "https://remote.mcp.server/sse"]
    }
  }
}
```

## Common flags

| Flag | Purpose |
|------|---------|
| `-y` | Auto-accept npx install prompt |
| `@latest` | Force check for latest version |
| `--header "Key: Value"` | Add custom request header |
| `--transport sse-only\|http-only\|sse-first\|http-first` | Control transport strategy (default: `http-first`) |
| `--allow-http` | Allow HTTP (non-TLS) connections |
| `--debug` | Write verbose logs to `~/.mcp-auth/<hash>_debug.log` |
| `--silent` | Suppress default logs |
| `--resource <url>` | Isolate OAuth session (for multiple instances of same server) |
| `--ignore-tool <pattern>` | Filter out tools by name/wildcard |
| `--auth-timeout <seconds>` | OAuth callback timeout (default: 30) |
| `--enable-proxy` | Use `HTTP_PROXY`/`HTTPS_PROXY` env vars |
| `--static-oauth-client-metadata <json\|@path>` | Provide static OAuth client metadata |
| `--static-oauth-client-info <json\|@path>` | Provide static OAuth client info (pre-registered clients) |

## Custom headers (auth bypass)

```json
{
  "args": ["mcp-remote", "https://remote.mcp.server/sse",
           "--header", "Authorization:${AUTH_HEADER}"],
  "env": { "AUTH_HEADER": "Bearer <token>" }
}
```

Note: avoid spaces around `:` in `--header` values due to a Cursor/Claude Desktop (Windows) bug — put spaces in the env var instead.

## Multiple instances (isolated OAuth sessions)

Use `--resource` to give each instance a separate OAuth session:

```json
{
  "args": ["mcp-remote", "https://mcp.example.com/sse", "--resource", "https://tenant1.example.com/"]
}
```

## Troubleshooting

- Clear stale credentials: `rm -rf ~/.mcp-auth`
- Test the auth flow manually: `npx -p mcp-remote@latest mcp-remote-client https://remote.mcp.server/sse`
- Node.js 18+ required.
- VPN cert issues: set `NODE_EXTRA_CA_CERTS` env var to your CA cert `.pem` path.
- Debug logs: add `--debug` flag; logs written to `~/.mcp-auth/<server_hash>_debug.log`.

## Reference

- No `man mcp-remote` available; use `npx mcp-remote --help` as the primary reference.
