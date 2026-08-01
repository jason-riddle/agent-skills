---
name: paperless-postgres-mcp-query
description: >
  Use this skill when querying the Paperless-ngx PostgreSQL database via the
  `postgres` MCP server's `postgres_query` tool — discovering document IDs,
  checksums, titles, tags, correspondents, document types, custom fields, or
  task/ingest history. Triggers on requests like "find a document in
  Paperless", "search paperless by title", "get paperless document id",
  "list paperless tags", "what did paperless ingest recently", "find
  failed paperless tasks", "query the paperless database", or any read-only
  lookup against Paperless-ngx metadata. Also use when a Beancount ledger
  references a paperless document ID and the ID needs to be verified or
  resolved to a title/checksum. Do NOT use for writing, updating, or
  deleting rows — the MCP server exposes read-only queries.
---

# Paperless-ngx PostgreSQL MCP queries

Query the Paperless-ngx metadata database via the `postgres_query` MCP tool
for read-only lookups: document IDs, titles, checksums, tags, correspondents,
document types, custom fields, and ingest task history.

## When to use

- Resolve a document ID referenced in a Beancount file to its title/checksum.
- Find documents matching a title, content, correspondent, tag, or date range.
- Audit ingest failures or recent activity from `documents_paperlesstask`.
- Inspect the schema before running ad-hoc queries.

## Prerequisites

The `postgres` MCP server must be registered in the active opencode config
(see `opencode.jsonc` → `mcp.postgres`). The server connects to the
Paperless database using the connection string configured there — no
credentials are passed to the agent. Verify the server is available before
running queries; if `postgres_query` is not present, the MCP server is not
loaded in this session and this skill cannot be used.

Do NOT shell out to `psql`. The connection string is not guaranteed to be
resolvable from the agent's environment, and the MCP server is the only
blessed path. Run all queries through `postgres_query`.

## Schema overview

72 tables; the handful that matter for document lookups:

| Table | Purpose | ~Rows |
|-------|---------|-------|
| `documents_document` | Core document metadata (title, checksum, dates, FKs) | ~2.5k |
| `documents_tag` | Tag definitions (hierarchical via `tn_parent_id`, `tn_*`) | ~590 |
| `documents_document_tags` | M2M join: document_id ↔ tag_id | ~76 |
| `documents_correspondent` | Sender/source (e.g. "CloverLeaf PM", "IRS (Muni)") | ~250 |
| `documents_documenttype` | Type classification (Statement, Receipt, Tax Form, …) | ~32 |
| `documents_customfield` | Custom field definitions (monetary, string, date, …) | ~13 |
| `documents_customfieldinstance` | Per-document custom field values | ~56 |
| `documents_note` | Notes attached to documents | ~0 |
| `documents_storagepath` | Custom storage path configs | 0 |
| `documents_paperlesstask` | Celery ingest/OCR task log (success/failure) | ~7.7k |
| `auditlog_logentry` | Django audit log (edits, tag changes, …) | ~240 |

Key `documents_document` columns: `id`, `title`, `content` (extracted text,
searchable), `checksum` (MD5), `archive_checksum`, `created` (date), `added`
(timestamp), `modified`, `correspondent_id`, `document_type_id`,
`storage_path_id`, `owner_id`, `mime_type`, `page_count`,
`original_filename`, `archive_filename`, `archive_serial_number`,
`deleted_at` (soft-delete), `restored_at`, `transaction_id`.

Tags are flat in practice (`tn_level = 1`, `tn_parent_id` is NULL for all
top-level tags). Do not assume a deep tree; query `tn_parent_id IS NULL`
for the root set. `documents_tag.is_inbox_tag` marks the special "Inbox" tag
(id 2) and the legacy "Renamed (Workflow)" tag (id 14).

Custom field values are sparse and polymorphic —
`documents_customfieldinstance` has one value column per data type
(`value_text`, `value_bool`, `value_monetary`, `value_date`, …). Coalesce
them when reading. Custom fields in use: `Cash Paid (USD)`,
`Tax Package Type`, `Reference ID`, `Previous Filename`, `For Tax Period
Ending Date`, `Created Date`, `Status`, `Work Order ID`, and a few others.

## Workflow

1. Confirm the MCP server is loaded: attempt a trivial
   `SELECT 1` via `postgres_query`. If the tool is missing, stop and tell
   the user the `postgres` MCP server is not registered in this opencode
   config.
2. Start with the **Schema overview** query (Q1) and **Row counts** (Q2)
   to orient — never assume table names or row scales from memory.
3. Pick the query below closest to the intent. All are parameterized with
   `:placeholder` tokens — substitute before running.
4. For lookups by title/content, prefer `ILIKE '%...%'` (Paperless titles
   vary in capitalization) and `LIMIT` results.
5. Cross-check document IDs against `deleted_at IS NULL` if a soft-delete
   filter matters; otherwise include all rows.

## Top 12 queries

### Q1 — Schema overview: list all tables with row counts

Purpose: orient before any ad-hoc query; confirm a table exists.

```sql
SELECT
  relname AS table_name,
  n_live_tup AS row_count
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;
```

### Q2 — Column schema for `documents_document`

Purpose: confirm column names/types before writing a query against the
core table. Replace `documents_document` with any other table name as
needed.

```sql
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'documents_document'
ORDER BY ordinal_position;
```

### Q3 — Recently added documents

Purpose: find what was just ingested (e.g. via email rule or upload).
`added` is the ingest timestamp; `created` is the document's own date.

```sql
SELECT
  id,
  title,
  created,
  added,
  mime_type,
  page_count,
  original_filename
FROM documents_document
WHERE deleted_at IS NULL
ORDER BY added DESC
LIMIT 20;
```

### Q4 — Search documents by title pattern

Purpose: the most common lookup — find a document by partial title.
Case-insensitive via `ILIKE`.

```sql
SELECT
  id,
  title,
  created,
  checksum,
  original_filename
FROM documents_document
WHERE deleted_at IS NULL
  AND title ILIKE '%:pattern%'
ORDER BY created DESC
LIMIT 50;
```

### Q5 — Search documents by extracted content

Purpose: full-text search over the OCR'd `content` column when the title
doesn't match. `content` holds the extracted plaintext.

```sql
SELECT
  id,
  title,
  created
FROM documents_document
WHERE deleted_at IS NULL
  AND content ILIKE '%:keyword%'
ORDER BY created DESC
LIMIT 50;
```

### Q6 — Documents by correspondent

Purpose: list every document from a given sender (bank, property manager,
IRS, etc.). Join on `documents_correspondent`.

```sql
SELECT
  d.id,
  d.title,
  d.created,
  d.added,
  c.name AS correspondent
FROM documents_document d
JOIN documents_correspondent c ON d.correspondent_id = c.id
WHERE d.deleted_at IS NULL
  AND c.name ILIKE '%:correspondent%'
ORDER BY d.created DESC;
```

### Q7 — Document count by correspondent

Purpose: see who sends the most documents; spot duplicates or filing
gaps. Drop the `HAVING` filter to list all correspondents.

```sql
SELECT
  c.name AS correspondent,
  COUNT(d.id) AS doc_count
FROM documents_correspondent c
LEFT JOIN documents_document d
  ON c.id = d.correspondent_id AND d.deleted_at IS NULL
GROUP BY c.name
ORDER BY doc_count DESC
LIMIT 30;
```

### Q8 — Document count by document type

Purpose: distribution of Statements, Receipts, Tax Forms, etc.

```sql
SELECT
  dt.name AS doc_type,
  COUNT(d.id) AS doc_count
FROM documents_documenttype dt
LEFT JOIN documents_document d
  ON dt.id = d.document_type_id AND d.deleted_at IS NULL
GROUP BY dt.name
ORDER BY doc_count DESC;
```

### Q9 — Document count by tag (top tags)

Purpose: see which tags are most used; identify the Inbox backlog or
ACTION NEEDED workload by filtering `t.name`.

```sql
SELECT
  t.name AS tag_name,
  COUNT(dt.document_id) AS doc_count
FROM documents_tag t
LEFT JOIN documents_document_tags dt ON t.id = dt.tag_id
LEFT JOIN documents_document d ON dt.document_id = d.id
  AND d.deleted_at IS NULL
GROUP BY t.name
ORDER BY doc_count DESC
LIMIT 30;
```

### Q10 — Documents with a specific tag (e.g. Inbox, ACTION NEEDED)

Purpose: pull the working queue — unprocessed Inbox docs or documents
flagged for review. Substitute the exact tag name.

```sql
SELECT
  d.id,
  d.title,
  d.created,
  d.added,
  t.name AS tag_name
FROM documents_document d
JOIN documents_document_tags dt ON d.id = dt.document_id
JOIN documents_tag t ON dt.tag_id = t.id
WHERE d.deleted_at IS NULL
  AND t.name = ':tag_name'
ORDER BY d.added DESC;
```

### Q11 — Custom field values for a document

Purpose: read structured metadata (Cash Paid, Reference ID, Tax Period,
Previous Filename, …) attached to a document. The `COALESCE` picks the
populated value column for the field's data type.

```sql
SELECT
  cfi.document_id,
  d.title,
  cf.name AS field_name,
  COALESCE(
    cfi.value_text,
    cfi.value_long_text,
    cfi.value_bool::text,
    cfi.value_url,
    cfi.value_date::text,
    cfi.value_int::text,
    cfi.value_float::text,
    cfi.value_monetary,
    cfi.value_select,
    cfi.value_monetary_amount::text,
    cfi.value_document_ids::text
  ) AS value
FROM documents_customfieldinstance cfi
JOIN documents_customfield cf ON cfi.field_id = cf.id
JOIN documents_document d ON cfi.document_id = d.id
WHERE d.deleted_at IS NULL
  AND d.id = :doc_id
ORDER BY cf.name;
```

To find documents by a custom field value instead, swap the WHERE clause:

```sql
WHERE cfi.field_id = (
    SELECT id FROM documents_customfield WHERE name = ':field_name'
  )
  AND cfi.value_text ILIKE '%:value%'
```

### Q12 — Recent failed ingest tasks

Purpose: diagnose why a document didn't appear — duplicates, storage
errors, OCR failures. `documents_paperlesstask` is the Celery task log.
`result` holds the error message.

```sql
SELECT
  id,
  type,
  status,
  LEFT(result::text, 200) AS result_preview,
  date_created,
  date_done
FROM documents_paperlesstask
WHERE status = 'FAILURE'
ORDER BY date_created DESC
LIMIT 20;
```

For task status distribution (success vs failure vs started):

```sql
SELECT status, COUNT(*) AS task_count
FROM documents_paperlesstask
GROUP BY status
ORDER BY task_count DESC;
```

## Gotchas

- **Read-only.** The MCP `postgres_query` tool is read-only. Never attempt
  `INSERT`/`UPDATE`/`DELETE`/`TRUNCATE` — write back through the Paperless
  web UI or REST API instead.
- **`deleted_at` soft deletes.** 28 documents are soft-deleted in this
  database. Always filter `WHERE deleted_at IS NULL` unless deliberately
  querying the trash. The same applies to `documents_note`,
  `documents_customfieldinstance` (both have `deleted_at`).
- **`created` is a date, `added` is a timestamp.** `created` is the
  document's own date (often backdated — e.g. a 1991 paper scanned in
  2026); `added` is when Paperless ingested it. Use `added` for "recent"
  and `created` for "in date range YYYY".
- **Two date columns, one ingest column.** `modified` is the last edit
  timestamp; `added` is the first ingest. Do not confuse them when
  auditing "what changed recently" — `auditlog_logentry.timestamp` is the
  authoritative edit log.
- **Tags are flat, not a tree.** Despite the `tn_*` tree-node columns, all
  tags in this instance have `tn_level = 1` and `tn_parent_id IS NULL`.
  Query `tn_parent_id IS NULL` for the effective root set; do not write
  recursive CTEs expecting depth.
- **Two inbox tags exist.** `documents_tag.is_inbox_tag = true` matches
  both "Inbox" (id 2) and the legacy "Renamed (Workflow)" tag (id 14).
  Filter by `t.name = 'Inbox'` if you want only the live inbox.
- **Custom field values are polymorphic and sparse.**
  `documents_customfieldinstance` has one column per data type; only one
  is populated per row. Always `COALESCE` the value columns (see Q11).
  `value_monetary` stores a string like `'USD22.94'`;
  `value_monetary_amount` stores the bare numeric. Custom fields exist on
  only ~56 of ~2.5k documents — most documents have none.
- **`checksum` is MD5 of the original file; `archive_checksum` is MD5 of
  the archived PDF (often NULL when archiving is disabled).** Use
  `checksum` for duplicate detection. No duplicate checksums exist in
  this database — Paperless rejects them at ingest (visible as
  `FAILURE` tasks in `documents_paperlesstask`).
- **`archive_serial_number` is almost always NULL.** Only 2 of ~2.5k
  documents have one. Do not rely on it as a stable identifier; use `id`.
- **`documents_storagepath` is empty.** No custom storage paths are
  configured; `storage_path_id` is NULL on every document. Skip
  storage-path joins.
- **`documents_note` is empty.** No notes are attached to any document.
  Do not expect note content.
- **Title format convention.** Titles follow
  `YYYY-MM-DD <Correspondent> ----- <Description>` (with literal ` ----- `
  separator) for most documents. Search the part after the separator to
  match descriptions regardless of date/correspondent prefix:
  `title ILIKE '%-----%description%'`.
- **`content` is the OCR'd plaintext**, not the raw PDF. It is
  searchable with `ILIKE` but may contain OCR errors; prefer `title`
  lookups when precision matters.
- **Task `result` column is text.** Cast with `result::text` and truncate
  with `LEFT(..., 200)` to avoid huge payloads in the response.
- **Do not use `psql`.** The database host (`nas...:32768`) may not be
  resolvable from the agent's environment, and credentials should not be
  handled directly. Always go through `postgres_query`.

## Output format

When returning document lookups, prefer a compact table:

```
id | created    | title
3232 | 2026-08-01 | 2026-08-01 DigitalOcean Receipt ----- 157559205
```

For schema discovery, return the raw column list. For counts, return the
two-column `name | count` table. Always include `id` in document result
sets — downstream ledger/Beancount references use it.
