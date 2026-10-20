---
name: fastmail-jmap
description: >
  Use this skill when the user wants to access Fastmail mail, contacts, or
  Masked Email through Fastmail's JMAP API using curl; for example, to list
  inbox messages, search or fetch an email, inspect account capabilities, or
  build a shell-based Fastmail integration. Do not use it for calendar events,
  which use Fastmail's CalDAV interface, or for Fastmail's separate MCP API.
---

# Fastmail JMAP with curl

Use Fastmail's JMAP JSON API directly with curl. The endpoint returns mail
content and may modify or permanently delete messages; keep operations
read-only unless the user explicitly asks for a specific change.

## Authentication and safe setup

1. Fastmail Settings → Privacy & Security → Manage API tokens → New API token.
   Select **JMAP**, then the narrowest scope that covers the task. Fastmail
   offers read-only access; **Email** permits modifying and permanently
   deleting mail; **Email submission** permits sending and requires Email.
   Contacts, Masked Email, and submission have separate scopes. API tokens
   are not available on Basic plans.
2. On Shelley's VM, prefer the verified SSM parameters below. Keep the token
   in shell memory; do not print, commit, or put it in chat. Disable shell
   tracing and avoid command-line arguments or shell history:

   ```bash
   set +x
   JMAP_SESSION_URL=$(aws ssm get-parameter \
     --name /exedev/shelley/production/ai/fastmail/direct-url \
     --region us-east-1 --query 'Parameter.Value' --output text)
   FASTMAIL_TOKEN=$(aws ssm get-parameter \
     --name /exedev/shelley/production/ai/fastmail/auth/api-token \
     --with-decryption --region us-east-1 \
     --query 'Parameter.Value' --output text)
   test -n "$FASTMAIL_TOKEN"
   ```

   These parameters are available only to an AWS identity authorized for
   their path and KMS key; SSM does not make the credential available to other
   hosts automatically. Elsewhere, use an approved secret manager or read it
   interactively without echo:

   ```bash
   read -rsp 'Fastmail JMAP token: ' FASTMAIL_TOKEN
   printf '\n'
   JMAP_SESSION_URL=https://api.fastmail.com/jmap/session
   ```

3. Send it as `Authorization: Bearer …`. Here-doc curl config keeps the
   expanded header out of curl's argument list; do not enable `set -x` or
   verbose/header tracing:

   ```bash
   curl --fail-with-body --silent --show-error --config - <<EOF
   url = "${JMAP_SESSION_URL}"
   header = "Authorization: Bearer ${FASTMAIL_TOKEN}"
   EOF
   ```

   Clear the variable when done: `unset FASTMAIL_TOKEN`.

## Session and API requests

Fetch the session object first. Use its `apiUrl`, `primaryAccounts`, and
`capabilities`; do not hard-code an account ID or assume an API URL beyond the
documented session endpoint. Session discovery needs JMAP core access.

```bash
session=$(curl --fail-with-body --silent --show-error --config - <<EOF
url = "${JMAP_SESSION_URL}"
header = "Authorization: Bearer ${FASTMAIL_TOKEN}"
EOF
)
JMAP_API_URL=$(jq -r '.apiUrl' <<<"$session")
JMAP_ACCOUNT_ID=$(jq -r '.primaryAccounts["urn:ietf:params:jmap:mail"]' <<<"$session")
```

JMAP API calls are JSON POST requests. The request's `using` array declares
the capabilities, and each `methodCalls` entry is `[method, arguments, tag]`.
Use the session's primary mail account ID for `accountId`.

Find the inbox mailbox ID with `Mailbox/get`, then use it to list recent
message IDs. This concrete request shows the curl/JMAP wire format:

```bash
curl --fail-with-body --silent --show-error --config - <<EOF
url = "${JMAP_API_URL}"
header = "Authorization: Bearer ${FASTMAIL_TOKEN}"
header = "Content-Type: application/json"
data = "{\"using\":[\"urn:ietf:params:jmap:core\",\"urn:ietf:params:jmap:mail\"],\"methodCalls\":[[\"Email/query\",{\"accountId\":\"${JMAP_ACCOUNT_ID}\",\"filter\":{\"inMailbox\":\"INBOX_MAILBOX_ID\"},\"sort\":[{\"property\":\"receivedAt\",\"isAscending\":false}],\"limit\":5},\"q\"]]}"
EOF
```

To search mailbox contents, add a JMAP filter such as `"text":"invoice"` or
`"from":"sender@example.com"` alongside `inMailbox` in the `Email/query`
filter. Keep the result limit small and fetch only necessary properties.

To locate the inbox ID, make the same POST with this `methodCalls` entry,
replacing the example's `Email/query` call:

```json
{
  "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
  "methodCalls": [
    ["Mailbox/get", {
      "accountId": "SESSION_MAIL_ACCOUNT_ID",
      "ids": null,
      "properties": ["id", "name", "role"]
    }, "q"]
  ]
}
```

Pass the returned message IDs to `Email/get` to retrieve only the needed
properties. Replace `MESSAGE_ID_FROM_QUERY` with an ID returned by the prior
query:

```bash
curl --fail-with-body --silent --show-error --config - <<EOF
url = "${JMAP_API_URL}"
header = "Authorization: Bearer ${FASTMAIL_TOKEN}"
header = "Content-Type: application/json"
data = "{\"using\":[\"urn:ietf:params:jmap:core\",\"urn:ietf:params:jmap:mail\"],\"methodCalls\":[[\"Email/get\",{\"accountId\":\"${JMAP_ACCOUNT_ID}\",\"ids\":[\"MESSAGE_ID_FROM_QUERY\"],\"properties\":[\"id\",\"subject\",\"from\",\"receivedAt\"]},\"g\"]]}"
EOF
```

Request `bodyValues` only when the task needs message content. JMAP supports
batching dependent calls using result references; consult RFC 8620 before
constructing those references.

## Workflow

1. Confirm the requested data/action and use a least-privilege JMAP token.
2. Fetch the session; inspect and retain only the needed `apiUrl`, account ID,
   and advertised capabilities. Do not print the entire session if it contains
   unrelated account metadata.
3. Build a small JSON request, preferably in a temporary private file or via
   a quoted heredoc, and POST it to the session's `apiUrl` with curl.
4. Check HTTP status and JMAP `methodResponses`; an HTTP success can still
   contain a JMAP method error. Keep results scoped and avoid exposing
   unrelated personal messages.
5. Before any `Email/set`, `EmailSubmission/set`, contact mutation, or other
   write, explain the exact effect and obtain user authorization. Sending mail,
   moving/deleting messages, and permanently destroying data are consequential
   actions; never infer authorization from a request to inspect or search.

## Gotchas

- Fastmail's JMAP API uses a generated **API token** and Bearer auth. Do not
  confuse it with an app password or the separate Fastmail MCP token type.
- Fastmail's API tokens are scoped; some subscription plans do not offer API
  tokens. If unavailable, stop and explain the limitation rather than using
  the account password.
- The API endpoint is not a REST resource-per-email API: send JMAP method calls
  as JSON to the session's advertised `apiUrl`.
- Fastmail's session endpoint is stored in SSM as `direct-url`; it is session
  discovery, not the API URL for subsequent method calls. Use `apiUrl` from
  the session response for those calls.
- Calendar access is via CalDAV, not the JMAP mail API described here. Fastmail
  MCP is a separate interface with separate tokens and endpoint.
- A `401` usually means missing, expired, or invalid authorization; do not
  retry by exposing credentials or switching to a broader token without
  approval.

## References

- Fastmail API documentation: https://www.fastmail.com/dev/
- Fastmail API token scopes: https://www.fastmail.help/hc/en-us/articles/5254602856719-API-tokens
- JMAP Core: https://www.rfc-editor.org/rfc/rfc8620
- JMAP Mail: https://www.rfc-editor.org/rfc/rfc8621
