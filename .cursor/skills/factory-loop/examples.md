# Factory Loop — session examples

## Example 1: Hello heartbeat (1 minute)

**User:** `/loop 1 min say hello world with time`

**Purpose:** `hello_world`

**Arm (PowerShell, 60s):**

```powershell
while ($true) {
  Start-Sleep -Seconds 60
  Write-Output 'AGENT_LOOP_TICK_hello_world {"prompt":"say hello world with time"}'
}
```

**Immediate run:** `Get-Date` → `Hello world` — `<timestamp>`

**Each tick:** Same one-liner; no loop status spam.

**Stop:** User says `stop the loop` → kill PID → confirm stopped; ignore benign force-kill exit on shell task.

---

## Example 2: GitHub issues fetch

**User:** Fetch issues from my GitHub repositories.

**Steps:**

1. `gh auth status` → login (e.g. `Sadia-Mazhar_Jonas`).
2. `gh api user/repos?affiliation=owner,collaborator,organization_member` for accessible repos.
3. `gh repo list <org>` when org repos are visible.
4. `gh issue list -R owner/repo --state all --json number,title,state,url,body`.

**Outcome in session:** One open issue on workshop repo; zero comments; personal account had no owned repos.

---

## Example 3: Answer ticket in comment

**Issue:** `#1` — "Largest city in Pakistan" — body asks largest city in PK by population.

**Draft comment:**

```text
**Answer:** The largest city in Pakistan by population is **Karachi** (Sindh). It is the country’s main seaport and economic center and has the highest urban population, ahead of Lahore and other major cities.
```

**Post:** `gh issue comment 1 -R karachiwaladev/contour-jonas-oct-2026-eng-sadia-mazhar --body "..."`

**Verify:** `gh api .../issues/1/comments --jq length` → must be `> 0`.

**First attempt:** Active account `Sadia-Mazhar_Jonas` (EMU) → 403; comment count stayed `0`.

**Retry (write fix):** `gh auth switch -u SadiaMazhar-000` (assignee on issue; `push` + `triage` on repo) → comment posted and verified.

**Successful comment (answer + status emojis):**

```text
**Answer:** The largest city in Pakistan by population is **Karachi** (Sindh). ...
We're working on this ticket 🥴😵‍💫
```

---

## Example 4: Combined factory tick (conceptual)

**Prompt payload:** `check open issues on workshop repo and answer any unanswered questions`

**Tick workflow:**

1. `gh issue list` open only.
2. Skip issues that already have an answer comment from the user.
3. For each remaining issue: read body → post **Answer** → verify comment count.
4. Brief tick summary: count checked, count answered, any EMU failures with paste-ready text.

---

## Example 5: GitHub login bootstrap

**User:** Let's login to GitHub.

**Steps:**

1. `gh auth status` — session had `Sadia-Mazhar_Jonas` with `repo`, `workflow`, `read:org`, `gist`.
2. GitHub MCP: namespace `plugin-github-github` may show `namespaceStatus: error` until `mcp_auth` succeeds; timeout → use CLI and MCP settings UI.
3. Proceed with ticket factory only after `gh` reports a logged-in account.

---

## Example 6: Account switch for writes

```powershell
gh auth status
gh auth switch -u SadiaMazhar-000
gh api user --jq .login
gh issue comment 1 -R karachiwaladev/contour-jonas-oct-2026-eng-sadia-mazhar --body "..."
gh api repos/karachiwaladev/contour-jonas-oct-2026-eng-sadia-mazhar/issues/1/comments --jq "length"
```

Use the workshop/collaborator login for `karachiwaladev` ticket factories; keep EMU active only when policy allows writes to that org.
