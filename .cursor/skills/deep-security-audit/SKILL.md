---
name: deep-security-audit
description: Runs evidence-driven repository security audits, changed-code security reviews, finding investigation, and remediation revalidation. Use for release security gates, security-sensitive changes, threat modeling, or explicit deep security audits.
---

# Deep security audit

Use only on repositories and infrastructure the user is authorized to assess.
Start read-only. Do not deploy, change production controls, exploit live
systems, expose secrets, or apply fixes without approval.

This repository is in **configuration-only mode**: DeepSec and Cloudflare
skills are not installed. Do not install, initialize, authenticate, or run
either without a new explicit approval that includes provider, source
transmission, and cost.

## Start an audit

1. Define the scope: repository/ref, changed files or release, excluded paths,
   authorized targets, time/cost cap, and evidence location.
2. Copy `docs/security/_audit-template.md` to
   `docs/security/audits/<date>-<scope>.md`.
3. Read `docs/security/baseline.md` and `docs/security/findings.md`.
4. Record each tool as `Run`, `Not run`, `Failed`, or `Blocked`, with the real
   reason. Never infer a result from configuration or documentation.
5. For DeepSec or Cloudflare decisions, read the matching file under
   `references/`.

## Establish or refresh the baseline

Map:

- trust boundaries and exposed assets;
- entry points and attacker-controlled inputs;
- authentication, authorization, sessions, and role transitions;
- sensitive data, secrets, logs, storage, and retention;
- privileged operations, hooks, shell execution, CI/CD, and deployment;
- APIs, outbound requests, file handling, queues, databases, and integrations;
- infrastructure providers and externally reachable services.

State unsupported or absent surfaces explicitly. Do not assume a deployment
platform from a dependency or documentation mention.

## Review coverage

Inspect relevant paths for:

- injection (DOM, SQL, command, template, prompt, and path);
- broken access control and business-logic authorization flaws;
- SSRF and unsafe outbound requests;
- insecure file upload, parsing, archive, and path handling;
- cryptographic misuse, weak randomness, and secret exposure;
- dependency and supply-chain vulnerabilities;
- insecure configuration, defaults, headers, and deployment permissions;
- logging, error handling, sensitive-data leakage, and auditability;
- rate limits, resource exhaustion, race conditions, and replay;
- session, token, cookie, and account-recovery handling;
- cross-file regressions and security-boundary changes.

Use safe local tests or static evidence. Do not probe an external target unless
the user identifies and authorizes it.

## Cursor changed-code review

For an explicitly requested changed-code security review:

1. Read Cursor's `review-security` skill.
2. Launch exactly one `security-review` subagent, foreground, with description
   exactly `Security Review`.
3. Use:

   ```text
   Full Repository Path: <absolute repository path>
   Diff: branch changes
   Custom Instructions: Trace affected trust boundaries and prioritize confirmed, exploitable vulnerabilities with concrete evidence.
   ```

   Use `Diff: uncommitted changes` only when requested.
4. Record the findings and limitations in the audit document. Do not fix or
   rerun without explicit user instruction.

Cursor review is changed-code evidence, not a repository-wide guarantee.

## DeepSec workflow

DeepSec is optional and currently unavailable. Before any future run:

1. Confirm the installed version and read its installed
   `.deepsec/node_modules/deepsec/SKILL.md`.
2. Present provider, source-transmission, sandbox, time, and maximum-cost
   details; obtain explicit approval.
3. Prefer the free local `scan` before paid `process`.
4. Process only pending/changed candidates; do not use reinvestigation or
   forced revalidation without a reason.
5. Revalidate confirmed High/Critical findings before remediation decisions.
6. Export findings, preserving DeepSec IDs and run/model metadata.

See `references/deepsec.md`. Documentation of a command is not permission to
run it.

## Cloudflare workflow

Use Cloudflare skills only when tracked configuration or user-confirmed
resources show that Cloudflare is in scope. Verify the exact installed skill
source first. This repository currently has none; record Cloudflare as N/A.

See `references/cloudflare.md`.

## Investigate each significant finding

1. Identify the entry point, attacker-controlled value, and affected asset.
2. Trace data and control flow across files and trust boundaries.
3. Identify attacker privileges and environmental preconditions.
4. Label the finding `Confirmed`, `Hypothesis`, `False positive`,
   `Remediated`, or `Risk accepted`.
5. Capture safe evidence. Never include secret values or weaponized payloads.
6. Recommend the smallest fix consistent with existing architecture.
7. Define a regression test and expected result where practical.
8. After approved remediation, rerun only the relevant checks and record the
   result, date, commit, and remaining uncertainty.

Copy `docs/security/_finding-template.md` for detailed findings and update the
summary ledger in `docs/security/findings.md`.

## Prioritization

Rank findings using all of:

- severity and impact;
- exploitability and attacker prerequisites;
- exposure and affected assets;
- evidence confidence;
- remediation effort and regression risk.

Critical/High findings remain Open until Remediated or explicitly Risk
accepted by a human owner. A scanner severity alone is not confirmation.

## Operating schedule

- Meaningful change: review changed code and affected boundaries.
- Before release: run applicable local checks, Cursor security review, and
  regression tests; DeepSec only if separately approved.
- Periodically: resume an incremental, cost-capped DeepSec scan if configured.
- After remediation: revalidate the finding and run its regression test.
- Infrastructure change: audit only the actual provider/configuration in scope.

Do not rescan unchanged code without a documented reason.

## Completion gate

Before declaring an audit complete:

- the scope and commit/range are recorded;
- actual tools/results, failures, cost, and limitations are recorded;
- every finding has evidence, status, root cause, impact, fix, regression test,
  and verification state, or an explicit N/A reason;
- unresolved Critical/High findings are listed and not silently downgraded;
- claims say what was covered, never “secure” or “zero vulnerabilities”.
