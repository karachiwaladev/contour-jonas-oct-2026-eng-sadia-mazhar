# Cloudflare reference

Official catalog: https://github.com/cloudflare/skills

Cloudflare skills and MCP tools are not installed, and this repository has no
Wrangler configuration, Worker entry point, bindings, or confirmed Cloudflare
resources. Record Cloudflare review as **N/A** unless that changes.

## Applicability check

Before loading or installing Cloudflare guidance, verify at least one:

- tracked `wrangler.toml`, `wrangler.json`, or `wrangler.jsonc`;
- Worker/Pages entry points or `@cloudflare/*` dependencies;
- bindings for KV, R2, D1, Durable Objects, Queues, Workflows, or secrets;
- user-confirmed Cloudflare account/resource identifiers;
- infrastructure changes explicitly targeting Cloudflare.

A domain using Cloudflare DNS is not enough to infer application-platform
scope.

## Skill selection

If Cloudflare becomes applicable, inspect the exact installed Skill source and
select only the relevant product guidance, for example:

- `workers-best-practices` for Worker runtime/configuration review;
- `wrangler` or `cf-cli` for CLI and resource operations;
- `durable-objects` for state/authorization/storage boundaries;
- `cloudflare-one` for Access/Gateway/Tunnel controls;
- `turnstile-spin` for server-side Siteverify handling;
- `sandbox-next` or `sandbox-stable` for isolated execution.

Do not load the whole catalog as a substitute for identifying actual
resources.

## Review focus

For confirmed Cloudflare resources, review:

- least-privilege API tokens, member roles, and CI identities;
- secret vs plain-text variables and accidental binding exposure;
- route/domain ownership and environment separation;
- authentication and authorization before Durable Object/storage access;
- outbound fetch destinations, SSRF controls, and service bindings;
- cache behavior involving private or authorization-dependent responses;
- rate limits, abuse controls, logging, and sensitive-data retention;
- deployment diffs and rollback evidence.

## Safety gate

Cloudflare installation, authentication, API/MCP calls, resource reads, and
configuration/deployment changes require explicit approval. Default to
read-only inspection. Never deploy, rotate secrets, modify policies, or probe a
live target as part of this Skill.
