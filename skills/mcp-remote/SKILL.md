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

## OAuth scope compatibility

As of 2026-08-22, the latest npm release is `mcp-remote@0.1.43`. Verify the
version before diagnosing an OAuth scope issue:

```bash
npm view mcp-remote version
npx -y mcp-remote@latest --help
```

The common failure is an OAuth authorization URL containing:

```text
scope=openid+email+profile
```

This can produce `invalid_scope` when the authorization server does not use
scopes. It is important to distinguish these metadata cases:

- `scopes_supported: []`: fixed in `0.1.39` by PR [#240](https://github.com/geelen/mcp-remote/pull/240).
- `scopes_supported` omitted: still falls back to `openid email profile` in `0.1.43`.

PR [#254](https://github.com/geelen/mcp-remote/pull/254) proposed handling both
empty and omitted scopes, but it was closed as a duplicate of #240. The merged
implementation intentionally retains the OIDC fallback when the metadata omits
`scopes_supported`. PR #240's merge event is documented at
<https://github.com/geelen/mcp-remote/pull/240#event-29826521934>; #254's close
event is at <https://github.com/geelen/mcp-remote/pull/254#event-29828880716>.

### Confirm the server metadata

Inspect both OAuth metadata endpoints. Use the resource URL from the server's
`WWW-Authenticate` response when it provides one:

```bash
curl -sS https://example.com/.well-known/oauth-protected-resource
curl -sS https://example.com/.well-known/oauth-authorization-server
```

If both responses omit `scopes_supported`, the current `mcp-remote` release
will use the fallback scope. If either relevant metadata response explicitly
contains `"scopes_supported": []`, `0.1.39+` should omit the scope.

### Reproduce without changing the user's OAuth cache

Use a temporary home directory and a sufficiently long timeout. A short
timeout can kill the process before the browser callback and is unrelated to
the scope bug:

```bash
mkdir -p /tmp/mcp-remote-oauth-test
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"oauth-test","version":"1.0"}}}' \
| timeout 35 env HOME=/tmp/mcp-remote-oauth-test \
  npx -y mcp-remote@latest https://example.com/mcp \
  --auth-timeout 20 --transport http-only --debug
```

In the debug output, check `scopes_supported` during discovery and the printed
authorization URL. For a server that omits the field, a result containing both
`Using fallback default scope` and `scope=openid+email+profile` confirms the
issue is still present in that release.

### Cloudflare-specific status

As of 2026-08-22, `https://mcp.cloudflare.com/mcp` is still affected:

- Protected-resource metadata omits `scopes_supported`.
- Authorization-server metadata omits `scopes_supported`.
- `mcp-remote@0.1.43` logs `Using fallback default scope`.
- The generated authorization URL contains `scope=openid+email+profile`.

Therefore upgrading from `0.1.38` to `0.1.43` does **not** fix the Cloudflare
OAuth failure. Do not remove a working workaround solely because #240 appears
in the release notes. Re-test after a future release by checking the generated
URL; the expected fix for Cloudflare is that the URL has no `scope` parameter
when both metadata documents omit `scopes_supported`.

## Reference

- No `man mcp-remote` available; use `npx mcp-remote --help` as the primary reference.
