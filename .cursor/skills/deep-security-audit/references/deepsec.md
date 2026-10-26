# DeepSec reference

Sources:

- https://deepsec.sh/docs/getting-started
- https://deepsec.sh/docs/architecture
- https://deepsec.sh/docs/models
- https://deepsec.sh/docs/faq
- https://github.com/vercel-labs/deepsec

Verify these against the installed version before use. DeepSec is not installed
in this repository; the commands below are documentation, not authorization.

## Setup modes

- `npx deepsec init --plan --output json`: previews setup state, but `npx` may
  still download/cache the package.
- `npx deepsec init --scaffold-only`: writes `.deepsec/`; it does not install,
  authenticate, scan, or process.
- `npx deepsec init`: scaffolds, installs dependencies, configures model
  access, analyzes the repository, scans, and begins paid AI processing.

After installation, read `.deepsec/node_modules/deepsec/SKILL.md` first because
it matches the installed CLI.

## Providers and transmission

DeepSec supports:

- Vercel AI Gateway;
- direct OpenAI or Anthropic credentials;
- Pi/custom HTTPS providers;
- an existing machine-wide Codex or Claude login (`--model-auth local`).

`process` and `revalidate` send relevant source to the configured model
provider. Direct-provider retention follows that provider's policy. Never place
credential values in tracked config; DeepSec stores the environment-variable
name, while values belong in approved local secret storage.

## Pipeline

From an initialized `.deepsec/` workspace:

```text
pnpm deepsec status
pnpm deepsec scan
pnpm deepsec process
pnpm deepsec revalidate
pnpm deepsec report
pnpm deepsec export --format md-dir --out ./findings
```

- `scan`: local regex/pattern matching; no model cost.
- `process`: AI investigation of pending candidates; paid.
- `triage`: finding-text prioritization; approximately $0.01/finding.
- `revalidate`: rereads code/history and records true-positive,
  false-positive, fixed, or uncertain; cost is comparable to `process`.

The workflow is incremental. `process` handles pending work; `revalidate`
handles findings without a verdict. Avoid `--reinvestigate` and `--force`
unless the audit records why unchanged work must be repeated.

## Published cost guidance

DeepSec's published Claude Opus estimates are:

- 100 files: $25–60;
- 500 files: $130–300;
- 2,000 files: $500–1,200.

Complexity can vary cost by 2–3×. Before any paid run, obtain approval for the
provider and cap. Recommended first calibration for this small repository:

```text
budget model profile
--limit 10
--max-cost-usd 5
--max-duration 30m
```

No estimate guarantees the final cost; stop and report limit/quota failures.

## Sandboxing

Optional Vercel Sandbox workers keep real model credentials on the host and
broker them only at provider egress. Egress is restricted during agent
execution, but repository source is uploaded to the sandbox and relevant code
still reaches the model provider. Sandboxing therefore requires separate
approval and is not a substitute for authorization.

Use sandboxing for untrusted inputs only after reviewing the installed
version's threat model, egress policy, project link, and billing.

## Approval gate

Before installation, initialization, setup, processing, revalidation, triage,
sandboxing, or source transmission, present:

1. exact DeepSec version and command;
2. files/configuration it will write;
3. provider and credential route;
4. source/log transmission and retention;
5. sandbox/network behavior;
6. cost, duration, and file limits;
7. authorized repository/ref and exclusions.

Proceed only after explicit approval. A local `scan` still requires approval
for package download/install and filesystem changes.
