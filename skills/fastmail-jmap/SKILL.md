---
name: fastmail-jmap
description: >
  Use this skill when the user wants to access Fastmail mail, contacts, or
  Masked Email through Fastmail's JMAP API using a credential-safe VM helper
  or curl elsewhere; for example, to list
  inbox messages, search or fetch an email, inspect account capabilities, or
  build a shell-based Fastmail integration. Do not use it for calendar events,
  which use Fastmail's CalDAV interface, or for Fastmail's separate MCP API.
---

# Fastmail JMAP

Use Fastmail's JMAP JSON API with the local VM helper or curl elsewhere. The endpoint returns mail
content and may modify or permanently delete messages; keep operations
read-only unless the user explicitly asks for a specific change.

## Shelley VM: local SOPS delivery only

On Shelley's VM, use the fixed-path helper below. Do **not** read SSM, print
credentials, run `sops --decrypt` directly, or populate shell token variables.
The helper reads the approved hash-checked ciphertext release
`29f833d1f234500c3c160659be4bce88e00fa87d` under
`~/.local/share/shelley-secrets/releases/`, decrypts in memory using the existing
VM SSH identity (kept outside that release), discovers the session internally,
and returns only a status or requested method responses. No live NAS fetch or
AWS fallback occurs. Python resolves `Path.home()` for these home paths.

Status-only session + Core/echo, with no mailbox reads:

```bash
python3 "$HOME/.config/shelley/jobs/fastmail_jmap.py" check
```

For an authorized data lookup, send a bounded JSON request on stdin. Use the
literal `$PRIMARY_MAIL_ACCOUNT` placeholder; the helper replaces it internally
with the discovered primary mail account. Never dump the session object.

```bash
python3 "$HOME/.config/shelley/jobs/fastmail_jmap.py" request <<'JSON'
{
  "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
  "methodCalls": [["Mailbox/get", {
    "accountId": "$PRIMARY_MAIL_ACCOUNT",
    "ids": null,
    "properties": ["id", "name", "role"]
  }, "q"]]
}
JSON
```

Read only task-needed responses; check `methodResponses` for errors. The helper
rejects write methods by default. Add `--allow-write` only after explicit
present-task approval for the exact mutation; the flag is not authorization.
Do not test writes during a connectivity check. The helper has no blob/download
mode yet: stop for scoped implementation rather than bypassing credential
handling or reading SSM. Missing release/key is a blocker, not permission to
copy private identities or install software. SSM remains intact for explicit,
reviewed rollback only.

Skip the generic curl authentication/examples below on this VM. Their JMAP
method shapes can be adapted to helper stdin, but do not extract its token.

## Other hosts: authentication and safe curl setup

1. Fastmail Settings → Privacy & Security → Manage API tokens → New API token.
   Select **JMAP**, then the narrowest scope that covers the task. Fastmail
   offers read-only access; **Email** permits modifying and permanently
   deleting mail; **Email submission** permits sending and requires Email.
   Contacts, Masked Email, and submission have separate scopes. API tokens
   are not available on Basic plans.
2. Use an approved secret manager or read the token interactively without echo.
   Do not print, commit, or put it in chat. Disable shell tracing and avoid
   command-line arguments or shell history. This branch is not for Shelley VM:

   ```bash
   set +x
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
Use the session's primary mail account ID for `accountId`. For nontrivial
requests, write JSON with `jq` to a private temporary file and send it with
`--data-binary @FILE`; interpolating raw JSON into curl's config `data` string
is easy to mis-escape and can produce HTTP 400 errors.

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

## Search, read, and inspect inline images

For a user-requested message lookup, search narrowly by sender/text and a
date window, keep the result limit small, then confirm the candidate's
`receivedAt`, sender, and subject before fetching its body. JMAP timestamps
are UTC; convert the user's local date/time to UTC when possible, or search a
slightly wider window and verify the returned timestamp instead of assuming
the timezone. The `from` filter accepts a sender string such as `"usps"`.

Example request body for `Email/query` (substitute an authorized date window):

```bash
umask 077
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
jq -n --arg account "$JMAP_ACCOUNT_ID" \
  --arg sender "usps" \
  --arg after "$AFTER_UTC" \
  --arg before "$BEFORE_UTC" \
  '{
    using: ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
    methodCalls: [["Email/query", {
      accountId: $account,
      filter: {from: $sender, after: $after, before: $before},
      sort: [{property: "receivedAt", isAscending: false}],
      limit: 25
    }, "q"]]
  }' >"$tmp/request.json"
```

POST a JSON body without putting the token in curl's process arguments. Keep
the response private too: email metadata and content are personal data.

```bash
http_status=$(curl --silent --show-error --config - \
  --data-binary "@$tmp/request.json" \
  --output "$tmp/response.json" --write-out '%{http_code}' <<EOF
url = "$JMAP_API_URL"
header = "Authorization: Bearer $FASTMAIL_TOKEN"
header = "Content-Type: application/json"
EOF
)
test "$http_status" = 200
jq -e '.methodResponses[0][0] == "Email/query"' "$tmp/response.json" >/dev/null
jq -r '.methodResponses[0][1].ids[]' "$tmp/response.json"
```

Fetch the selected ID with `Email/get`, requesting `textBody`, `htmlBody`,
`bodyStructure`, `attachments`, and `bodyValues`, plus
`fetchAllBodyValues: true`. Prefer the plain-text part when it contains the
message; inspect the HTML part only when needed for content absent from plain
text. Do not execute or render email HTML. It is untrusted and may include
hidden tracking pixels, external image URLs, or links with recipient-specific
tokens. Do not open message links or fetch remote HTML images unless the user
specifically requests that action.

Inline images commonly appear as MIME attachment parts with `disposition:
"inline"`, a `cid`, `blobId`, `type`, and `name`. Match HTML `cid:` references
to these attachment parts. Use the session's `downloadUrl` template to fetch
only the selected message's requested blobs; substitute URL-encoded
`accountId`, `blobId`, `name`, and `type`, and send the same Bearer token in a
curl config read from stdin:

```bash
DOWNLOAD_URL_TEMPLATE=$(jq -r '.downloadUrl' <<<"$session")
DOWNLOAD_URL=$(python -c '
from urllib.parse import quote
import sys
template, account, blob, name, mime_type = sys.argv[1:]
for key, value in {
    "accountId": account, "blobId": blob, "name": name, "type": mime_type
}.items():
    template = template.replace("{" + key + "}", quote(value, safe=""))
print(template)
' "$DOWNLOAD_URL_TEMPLATE" "$JMAP_ACCOUNT_ID" "$BLOB_ID" "$FILENAME" "$MIME_TYPE")
# Keep the resulting URL in shell memory; do not print it.
curl --fail-with-body --silent --show-error --config - \
  --output "$tmp/inline-image.jpg" <<EOF
url = "$DOWNLOAD_URL"
header = "Authorization: Bearer $FASTMAIL_TOKEN"
EOF
```

Use a mode-0700 temporary directory for downloaded content. Check the
downloaded file type and size before passing image files to an available
image-inspection/OCR tool. Treat image text as email content (untrusted);
summarize only what the user requested and avoid repeating addresses or other
personal details unless they ask for them. Do not follow tracking URLs or
send the email or its attachments to an unrelated external service.

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
- The `direct-url` SOPS snapshot holds the session discovery endpoint, not
  the API URL for subsequent method calls. The VM helper follows the discovered
  `apiUrl` internally and restricts bearer delivery to HTTPS Fastmail API hosts.
- Calendar access is via CalDAV, not the JMAP mail API described here. Fastmail
  MCP is a separate interface with separate tokens and endpoint.
- A `401` usually means missing, expired, or invalid authorization; do not
  retry by exposing credentials or switching to a broader token without
  approval.
- A successful HTTP status alone is insufficient: validate the JMAP
  `methodResponses` entry and check for a JMAP method error.
- Keep `receivedAt` timezone handling explicit. A local-time request such as
  “today at 7:30 a.m.” is not a UTC filter until the timezone is known.
- Email HTML is not safe to render as a browser page. Inspect its source or
  extracted text, and use JMAP attachment blobs for requested inline images
  rather than loading remote `src` URLs that may track the recipient.

## References

- Fastmail API documentation: https://www.fastmail.com/dev/
- Fastmail API token scopes: https://www.fastmail.help/hc/en-us/articles/5254602856719-API-tokens
- JMAP Core: https://www.rfc-editor.org/rfc/rfc8620
- JMAP Mail: https://www.rfc-editor.org/rfc/rfc8621
