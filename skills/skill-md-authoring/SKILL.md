---
name: skill-md-authoring
description: >
  Use this skill whenever the user wants to create, write, draft, scaffold,
  review, fix, or improve a SKILL.md file — the metadata + instructions file
  that defines an Agent Skill. Triggers on requests like "make a skill",
  "write a SKILL.md", "my skill isn't triggering", "review this skill's
  frontmatter", "fix this skill's description", or anytime a user pastes
  YAML frontmatter with `name:` and `description:` fields. Applies even when
  the user does not use the word "skill" but describes packaging instructions
  for an agent in a Markdown file with frontmatter.
---

# Authoring SKILL.md files

A `SKILL.md` file is the entry point of an Agent Skill: YAML frontmatter that
tells an agent *when* the skill applies, followed by Markdown that tells the
agent *what to do* once activated. This skill covers only the `SKILL.md` file
itself — not companion directories like `scripts/`, `references/`, or `assets/`.

## How a SKILL.md gets used

Agents load skills with progressive disclosure:

1. **At startup**, the agent reads only the `name` and `description` from the
   frontmatter of every available skill (~100 tokens each).
2. **When a user's request matches a description**, the agent loads the entire
   Markdown body into context.
3. **Anything else** (separate files, scripts) is loaded only on demand.

Two consequences follow:

- The `description` carries the entire triggering burden. If it does not convey
  *when* the skill is useful, the skill never activates.
- The body competes for context with the conversation and other skills. Keep it
  lean — under ~500 lines or ~5,000 tokens.

## Required structure

Every `SKILL.md` has exactly two parts: YAML frontmatter delimited by `---`,
then Markdown body content.

```markdown
---
name: skill-name
description: One to a few sentences describing what the skill does and when to use it.
---

# Skill title

Body content in Markdown.
```

## Frontmatter fields

| Field           | Required | Constraints                                                                 |
| --------------- | -------- | --------------------------------------------------------------------------- |
| `name`          | Yes      | 1–64 chars. Lowercase `a–z`, digits, hyphens. No leading/trailing/double `-`. Must match the skill's directory name. |
| `description`   | Yes      | 1–1024 chars. Non-empty. Must describe **what** the skill does *and* **when** to use it. |
| `license`       | No       | Short license name or reference to a bundled license file.                  |
| `compatibility` | No       | ≤500 chars. Environment requirements (intended product, required packages, network access). Omit unless genuinely needed. |
| `metadata`      | No       | Arbitrary string→string map. Use unique key names to avoid client conflicts. |
| `allowed-tools` | No       | Space-separated string of pre-approved tools. Experimental; support varies. |

### `name` rules

Valid: `pdf-processing`, `data-analysis`, `skill-md-authoring`.
Invalid: `PDF-Processing` (uppercase), `-pdf` (leading hyphen), `pdf--proc`
(consecutive hyphens), `my_skill` (underscore).

### `description` rules

The description does the triggering. Optimize it aggressively.

**Write it imperatively, addressed to the agent.** Frame it as an instruction
about when to act, not a summary of capabilities.

- Good: `Use this skill when the user wants to extract text or fill forms in PDFs...`
- Weak: `This skill helps with PDFs.`

**Cover both what and when.** A description must answer "what does this do?"
*and* "what does a triggering request look like?"

**Name the user's intent, not the implementation.** Agents match against what
the user asked for, not internal mechanics.

**Be pushy on coverage.** Explicitly list adjacent phrasings and cases where
the user describes the need without naming the domain — e.g., "even if they
don't explicitly mention 'CSV' or 'spreadsheet'."

**Stay under 1024 characters.** Descriptions tend to grow during iteration;
check the limit before saving.

#### Before / after

```yaml
# Before — too vague, no triggers
description: Process CSV files.

# After — what + when, intent-based, includes near-miss phrasings
description: >
  Analyze CSV and tabular data — compute summary statistics, add derived
  columns, generate charts, and clean messy data. Use this skill when the
  user has a CSV, TSV, or Excel file and wants to explore, transform, or
  visualize it, even if they don't explicitly say "CSV" or "analysis."
```

### Optional fields, briefly

```yaml
license: Apache-2.0
compatibility: Requires Python 3.11+ and pandas
metadata:
  author: example-org
  version: "1.2"
allowed-tools: Bash(git:*) Read
```

## Writing the body

There are no format rules for the body beyond standard Markdown. The following
patterns consistently produce skills agents use well.

### Write in imperative / infinitive form

Address actions, not actors. Drop "you" and "the agent".

- Good: `Extract the form fields with pdfplumber. Validate each field name against the schema before filling.`
- Avoid: `You should extract the form fields. The agent will then validate...`

### Add what the agent lacks; omit what it knows

Skip generic background (what a PDF is, what HTTP does). Spend tokens on
project conventions, non-obvious edge cases, specific APIs, and the *one*
preferred tool for the job.

### Provide a default, not a menu

When several approaches would work, pick one and mention alternatives as
escape hatches:

```markdown
Use `pdfplumber` for text extraction. For scanned PDFs requiring OCR, fall
back to `pdf2image` with `pytesseract`.
```

### Teach a procedure, not an answer

Describe how to approach the class of problem so the skill generalizes. Reserve
prescriptive, exact-command instructions for fragile or destructive operations
(migrations, deletions, deploys) where consistency matters more than judgment.

### Include a "Gotchas" section when relevant

Concrete corrections to mistakes the agent will otherwise make. These are the
highest-value content in many skills:

```markdown
## Gotchas

- The `users` table uses soft deletes. Always include `WHERE deleted_at IS NULL`.
- The same identifier is `user_id` in the database, `uid` in auth, and
  `accountId` in billing. They refer to the same value.
- `/health` returns 200 if the web server is up even when the DB is down.
  Use `/ready` for full readiness.
```

### Provide a template when output format matters

Agents pattern-match well against concrete structures. A short template in
the body beats a paragraph describing the format.

### Keep it under ~500 lines

If a skill legitimately needs more content, that content belongs in separate
reference files (outside the scope of this skill). Within a single `SKILL.md`,
prefer short, focused sections over exhaustive coverage.

## Recommended body skeleton

```markdown
---
name: <slug>
description: >
  <Imperative "use this skill when..." statement covering what + when,
  including near-miss phrasings, ≤1024 chars.>
---

# <Human-readable title>

<One- or two-sentence statement of purpose.>

## When to use

<Concrete examples of triggering requests. Optional if the description already
covers this well.>

## Workflow

1. <First step, with the specific tool or command to use.>
2. <Second step.>
3. <Validation / verification step.>

## Gotchas

- <Non-obvious fact #1>
- <Non-obvious fact #2>

## Output format

<Inline template if the skill produces structured output.>
```

## Validation checklist

Before finalizing a `SKILL.md`, verify each item:

**Frontmatter**
- [ ] Opens and closes with `---` on their own lines.
- [ ] `name` is 1–64 chars, lowercase alphanumeric + hyphens only, no leading/trailing/double hyphens.
- [ ] `name` matches the parent directory name exactly.
- [ ] `description` is non-empty and ≤1024 characters.
- [ ] `description` states both what the skill does and when to use it.
- [ ] `description` uses imperative trigger phrasing ("Use this skill when...").
- [ ] Optional fields, if present, respect their constraints.

**Body**
- [ ] Written in imperative form, no second person.
- [ ] Under ~500 lines / ~5,000 tokens.
- [ ] Provides a clear default approach rather than a menu of options.
- [ ] Includes gotchas / non-obvious facts where applicable.
- [ ] Teaches a reusable procedure, not a one-off answer.
- [ ] No padding explaining concepts the agent already knows.

## Common mistakes

**Vague description.** `description: Helps with PDFs.` triggers unpredictably.
Fix by listing intents and triggering phrasings.

**Capability-listing description.** `description: This skill provides PDF
parsing, form filling, and text extraction.` describes the skill instead of
instructing the agent. Reframe as `Use this skill when the user wants to...`.

**Description too narrow on keywords.** A description that only matches when
the user literally says "CSV" will miss "spreadsheet", "tabular data",
"xlsx file". Include the intent, not just the format name.

**Description too broad.** `Use this skill for any data task.` triggers on
unrelated requests. Add boundaries: what the skill does *not* cover, or what
makes a request a good fit.

**Body too long.** Comprehensive coverage of every edge case crowds context
and makes the agent pursue unproductive paths. Cut to the procedural core.

**Second-person voice.** "You should validate the input" reads as instruction
to the user, not the agent. Use "Validate the input."

**Name / directory mismatch.** `name: pdf_tools` in a directory called
`pdf-tools/` fails validation. Both must use the same lowercase-hyphen form.

## Two complete examples

### Minimal valid SKILL.md

```markdown
---
name: semver-bumper
description: >
  Use this skill when the user wants to bump a project's semantic version —
  for example "release a new patch", "cut a minor version", "what should
  the next version be?", or when editing a `version` field in package.json,
  pyproject.toml, or Cargo.toml. Determines the correct next version from
  recent commits and updates the appropriate manifest file.
---

# Semver bumper

## Workflow

1. Read the current version from the project manifest (`package.json`,
   `pyproject.toml`, or `Cargo.toml`).
2. Inspect commits since the last version tag using `git log <tag>..HEAD --oneline`.
3. Choose the bump level:
   - **major** — any commit message contains `BREAKING CHANGE` or `!:`.
   - **minor** — any commit starts with `feat:`.
   - **patch** — otherwise.
4. Update the manifest in place. Do not modify other fields.
5. Print the new version to stdout so the caller can tag it.

## Gotchas

- Pre-1.0 projects bump minor (not major) for breaking changes by convention.
- Some monorepos pin versions in multiple manifests; grep for the old version
  string before assuming a single file.
```

### Fuller example with template + gotchas

```markdown
---
name: incident-postmortem
description: >
  Use this skill when the user wants to write, draft, or review a postmortem
  / incident report / RCA for a production incident — including phrasings
  like "write up what happened", "draft an RCA", "post-incident review", or
  when the user describes an outage and asks for a document summarizing it.
  Produces a blameless postmortem in the team's standard format.
---

# Incident postmortems

Draft a blameless postmortem from incident artifacts (chat logs, metrics,
timelines) using the team's standard structure.

## Workflow

1. Collect the incident timeline from the user. Ask for: detection time,
   mitigation time, resolution time, and the customer-visible impact.
2. Identify the trigger (the change that caused the failure) separately from
   the root cause (the latent condition that allowed the trigger to cause harm).
3. Draft the report against the template below.
4. Before finalizing, verify every action item has an owner and a due date.

## Gotchas

- Keep the language blameless: describe systems and decisions, not individuals.
  Write "the deploy script proceeded without confirmation" not "Alice
  deployed without confirming".
- Detection time is when *humans* learned about the incident, not when the
  alert first fired. These often differ.
- "Root cause" is rarely singular. List contributing factors separately.

## Template

```markdown
# Incident: <short title>

**Status:** Resolved
**Severity:** S<n>
**Duration:** <detection → resolution>
**Customer impact:** <one sentence>

## Summary
<2–3 sentences a non-engineer can understand.>

## Timeline
- HH:MM — <event>
- HH:MM — <event>

## Trigger
<The proximate change that caused the failure.>

## Contributing factors
- <Latent condition #1>
- <Latent condition #2>

## What went well
- <…>

## What went poorly
- <…>

## Action items
| # | Item | Owner | Due |
|---|------|-------|-----|
| 1 |      |       |     |
```
```
