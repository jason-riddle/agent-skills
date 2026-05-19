---
name: browse-mortgage-info-at-spservicing.com
description: >-
  Use this skill when retrieving mortgage account information from SPS (Select Portfolio Servicing).
  Triggers on requests like "check my SPS mortgage", "get mortgage balance from spservicing",
  "view SPS account details", "download mortgage statement from SPS".
website: spservicing.com
authentication_required: true
agentcore_profile_id: spservicing_customer-rXTGNegodG
---

# Browse Mortgage Info at spservicing.com

**READ-ONLY**: Never click payment buttons, modify settings, or submit forms that change account state.

## Prerequisites

AgentCore browser profile with saved authentication:

```bash
export SPSERVICING_PROFILE_ID="spservicing_customer-rXTGNegodG"
export AGENT_BROWSER_PROVIDER=agentcore
export AGENTCORE_PROFILE_ID="$SPSERVICING_PROFILE_ID"
```

## Workflow

```bash
# 1. Open dashboard URL directly (checks auth state)
agent-browser-wrapper --session-name spservicing open https://www.spservicing.com/AccountInformationProcessing/ViewAccounts
sleep 3

# 2. Check if logged in (redirects to /Home/Login if not authenticated)
agent-browser-wrapper --session-name spservicing get url
# If on /Home/Login, user needs to authenticate manually

# 3. Once authenticated, navigate to Documents or Statements & Letters
agent-browser-wrapper --session-name spservicing snapshot -i

# Documents page
agent-browser-wrapper --session-name spservicing click @e<DOCUMENTS_NAV_REF>
sleep 3
agent-browser-wrapper --session-name spservicing get url  # Verify: /AccountInformationProcessing/Documents
agent-browser-wrapper --session-name spservicing snapshot -i

# Statements & Letters page
agent-browser-wrapper --session-name spservicing click @e<STATEMENTS_NAV_REF>
sleep 3
agent-browser-wrapper --session-name spservicing get url  # Verify: /AccountInformationProcessing/StatementsAndLetters
agent-browser-wrapper --session-name spservicing snapshot -i

# 4. Download a statement/letter
agent-browser-wrapper --session-name spservicing click @e<STATEMENT_ROW_REF>
sleep 2
# (PDF opens or downloads)

# 5. Close
agent-browser-wrapper --session-name spservicing close
```

## Site Structure

**Primary URLs:**
- Dashboard: `https://www.spservicing.com/AccountInformationProcessing/ViewAccounts`
- Documents: `https://www.spservicing.com/AccountInformationProcessing/Documents`
- Statements & Letters: `https://www.spservicing.com/AccountInformationProcessing/StatementsAndLetters`
- Login redirect: `https://www.spservicing.com/Home/Login?ReturnUrl=...` (if not authenticated)

**Dashboard (ViewAccounts):**
- Account selector dropdown (loan number button)
- Payment Information section (pending payments, "MAKE PAYMENT" button - READ-ONLY: never click)
- Account Details section ("DETAILED VIEW" button)
- Statements & Letters preview (LETTERS / DOCUMENTS tabs with recent entries)
- Important Information (ESCROW - TAX / ESCROW - INSURANCE tabs)
- Left nav: My Account, Statements & Letters, Documents

**Documents Page:**
- "Request Document(s)" button
- "Submit Documents" button
- (Document list may be empty or populated depending on account)

**Statements & Letters Page:**
- **Statements section:**
  - Year dropdown (2026, 2025, 2024, 2023, 2022)
  - Language options: "in English" / "en Español"
  - Table: Date | Statements
  - Rows: Monthly Statements-Electronic (clickable to view/download)

- **Letters section:**
  - Year dropdown (2026+)
  - Table: Date | Letters
  - Rows: Escrow Analysis Statement, other letters (clickable to view/download)

## Gotchas

**Authentication:**
- Always navigate to `/AccountInformationProcessing/ViewAccounts` first
- If redirected to `/Home/Login?ReturnUrl=...`, user must authenticate manually
- Login modal appears as overlay on homepage, doesn't navigate
- Session expires after ~15-30 minutes inactivity

**Navigation:**
- Documents and Statements & Letters pages may hang on first or second click attempt
- If page doesn't load after 5 seconds, retry the navigation click
- Allow 3 seconds after clicking nav links before checking URL
- Re-snapshot after any navigation

**Read-Only:**
- Never click: "MAKE A PAYMENT", "Request Document(s)", "Submit Documents", "Update Account", "Save Changes"

**Downloading Statements:**
- Clicking a statement row opens a new tab at `/AccountInformationProcessing/GetDocumentbyID`
- Chrome's native PDF viewer renders the document — body is empty, no accessible PDF URL
- `pdf` command captures the viewer chrome (toolbar, sidebar) not the raw document
- True PDF capture is not currently possible via AgentCore

**Elements:**
- Refs go stale after page changes
- Always re-snapshot before next interaction
