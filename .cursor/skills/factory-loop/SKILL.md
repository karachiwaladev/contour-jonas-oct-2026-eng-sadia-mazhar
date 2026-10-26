---
name: factory-loop
description: >-
  Run recurring local agent loops with standardized sentinels, Windows PowerShell
  wiring, brief tick replies, clean stop, and optional GitHub issue fetch/answer/comment.
  Use when the user mentions factory-loop, timed heartbeats with payloads, or ticket
  factories on a /loop schedule.
disable-model-invocation: true
---

# Factory Loop

Factory conventions for **local** recurring agent work. For mechanism selection (cloud timer vs local shell), read and follow the Cursor built-in **loop** skill or `/loop` command first; then apply this skill.

## Purpose slug

Derive a stable `<purpose>` from the user prompt:

- Lowercase, words joined with `_`, strip non-alphanumeric (except `_`)
- Example: `say hello world with time` → `hello_world`

| Kind | Sentinel | Regex for `notify_on_output` |
|------|----------|------------------------------|
| Fixed interval | `AGENT_LOOP_TICK_<purpose>` | `^AGENT_LOOP_TICK_<purpose>` |
| Dynamic wake | `AGENT_LOOP_WAKE_<purpose>` | `^AGENT_LOOP_WAKE_<purpose>` |

Payload on the same line as JSON: `{"prompt":"<literal prompt for each tick>"}`.

## Arm a fixed loop (local)

1. Grep terminals for an existing loop with the same sentinel; do not start duplicates.
2. Parse interval: `30s`, `1m`, `5m`, `2h` → seconds (`1 min` → `60`).
3. **Run the prompt once immediately** (before or right after arming; first sentinel must come only after the first sleep).
4. Start background shell with `block_until_ms: 0` and `notify_on_output` on the tick regex.
5. **Track the shell PID** for stop.
6. Confirm: interval, prompt already ran once, approximate first tick time, PID, and that the user can say **stop the loop**.

### PowerShell (Windows)

```powershell
while ($true) {
  Start-Sleep -Seconds <seconds>
  Write-Output 'AGENT_LOOP_TICK_<purpose> {"prompt":"<prompt>"}'
}
```

Shell command title: `Loop every <interval>: <short prompt>`.

### Bash (macOS/Linux)

```bash
while true; do
  sleep <seconds>
  echo 'AGENT_LOOP_TICK_<purpose> {"prompt":"<prompt>"}'
done
```

## On each tick

1. Execute the tick `prompt` once.
2. Keep the user message **brief** (one or two lines unless the prompt requires more).
3. If the system says to "briefly inform the user about the task result", that means run the tick prompt — not meta-commentary about the loop machinery.

### Timestamp heartbeat pattern

When the prompt includes time (session pattern):

```powershell
Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
```

User-facing line example:

`Hello world` — `2026-10-26 02:13:09 -04:00`

## Stop

1. Kill the tracked loop PID: `Stop-Process -Id <pid> -Force` or `taskkill /PID <pid> /F`.
2. Verify the process is gone; terminal may show `status: failed` and exit `4294967295` — **expected** after force kill.
3. Do not arm another wake or restart unless the user asks.
4. If a shell **completion** notification arrives after a user-requested stop, one short acknowledgment is enough; do not treat it as a new tick.

## GitHub ticket factory

Use on a tick or as a one-shot when the prompt says to handle tickets/issues.

### Auth (before ticket work)

1. `gh auth status` — if not logged in, run `gh auth login` (user must approve).
2. Optional Cursor GitHub MCP: `GetDynamicTools` on `plugin-github-github`; if only `mcp_auth` is listed or tools are in error, call `mcp_auth` once. On timeout, tell the user to reconnect GitHub under **Settings → MCP**; **gh** remains the fallback for issues.

### Discover

- Workspace: `git remote -v` for default repo.
- Account: `gh auth status`, `gh api user --jq .login`.
- Issues: `gh issue list -R owner/repo --state open --json number,title,body,url`.
- Full context: `gh issue view <n> -R owner/repo --json title,body,comments`.

### Respond

1. Read the **question** from title and body (not only the title).
2. Draft a concise factual **Answer** comment:

```text
**Answer:** <direct answer to the ticket question>
```

Optional in-progress line (emoji in comment body only; GitHub API reactions do not support arbitrary emoji):

```text
We're working on this ticket 🥴😵‍💫
```

3. Post: `gh issue comment <n> -R owner/repo --body "..."`.
4. **Verify:** `gh api repos/owner/repo/issues/<n>/comments --jq length` or `gh issue view <n> --comments`. If count is still `0`, the comment did not land.

### Multiple GitHub accounts (EMU vs workshop)

Before posting, run `gh auth status` and note the **active** account (`gh api user --jq .login`).

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| 403 `Enterprise Managed User` on comment | Active account is EMU; external org repo (e.g. `karachiwaladev`) | `gh auth switch -u <workshop-user>` then retry |
| Reads work, writes fail | Same as above | Use the assignee/collaborator login for that repo, not EMU |
| Comment URL returned but user sees nothing | Wrong account or verify skipped | `gh api repos/.../issues/<n>/comments --jq length` |

Workshop pattern (validated): **SadiaMazhar-000** can comment on `karachiwaladev/contour-jonas-oct-2026-eng-sadia-mazhar`; **Sadia-Mazhar_Jonas** (EMU) cannot write there.

If write still returns EMU 403 after switching:

- Do not bypass with alternate upload hosts or repeated identical posts.
- Provide exact markdown to paste on the issue in the browser.
- Enterprise policy requires admin change; repo settings alone do not fix EMU blocks.

## Checklist (agent)

```
- [ ] Read loop skill; pick cloud timer OR local monitored shell
- [ ] Unique <purpose> and sentinel
- [ ] No duplicate loop in terminals
- [ ] Prompt executed once before first tick
- [ ] PID tracked
- [ ] Tick output brief
- [ ] Stop kills PID; no re-arm unless asked
- [ ] GitHub: active account can write; switch with `gh auth switch` if EMU 403
- [ ] GitHub: verify comment count after post
```

## Examples

Session-derived flows: [examples.md](examples.md).
