# Cursor beforeShellExecution: enforce current-diff evidence before factory push.
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::UTF8
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

try {
  $raw = [Console]::In.ReadToEnd()
  if ([string]::IsNullOrWhiteSpace($raw)) { throw 'Missing hook payload.' }
  $payload = $raw | ConvertFrom-Json
  $root = (Get-Location).Path
  if ($payload.workspace_roots -and $payload.workspace_roots.Count) {
    $candidateRoot = [string]$payload.workspace_roots[0]
    if (-not [string]::IsNullOrWhiteSpace($candidateRoot) -and
        (Test-Path -LiteralPath $candidateRoot -PathType Container)) {
      $root = $candidateRoot
    }
  }
  if (-not (Test-Path (Join-Path $root '.cursor/factory-loop-active'))) {
    Write-Output '{"permission":"allow"}'
    exit 0
  }

  $branch = (git -C $root rev-parse --abbrev-ref HEAD 2>$null).Trim()
  if ($branch -notmatch '^factory/issue-\d+-[A-Za-z0-9][A-Za-z0-9._-]*$') {
    Write-Output (@{
      permission = 'deny'
      user_message = 'Factory-loop push blocked: branch must be factory/issue-<n>-<slug>.'
      agent_message = 'Use a verified default-branch base and the required ticket branch format.'
    } | ConvertTo-Json -Compress)
    exit 0
  }

  & powershell -NoProfile -ExecutionPolicy Bypass `
    -File (Join-Path $root '.cursor/tools/check-loop-security.ps1') `
    -Root $root *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Output (@{
      permission = 'deny'
      user_message = 'Factory-loop push blocked: machine-readable security-review receipt is missing, invalid, stale, or has blocking findings.'
      agent_message = 'Run the mandatory review, record its current-diff receipt with record-security-review.ps1, then retry. Audit Markdown cannot authorize a push.'
    } | ConvertTo-Json -Compress)
    exit 0
  }

  Write-Output (@{
    permission = 'ask'
    user_message = "Factory-loop review receipt matches the current diff on branch '$branch'. Approve this exact push to the verified origin?"
    agent_message = 'A local receipt is not tamper-proof. Push only after explicit human approval; PR review remains mandatory.'
  } | ConvertTo-Json -Compress)
  exit 0
} catch {
  Write-Output (@{
    permission = 'deny'
    user_message = 'Factory-loop push blocked because its security gate could not be evaluated.'
    agent_message = 'Fail closed; repair the local gate before retrying.'
  } | ConvertTo-Json -Compress)
  exit 0
}

Write-Output '{"permission":"allow"}'
exit 0
