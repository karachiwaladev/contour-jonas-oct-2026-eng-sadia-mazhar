param(
  [string]$Root = (Get-Location).Path,
  [switch]$Json
)

# Deterministic local gate. Cursor security-review itself is run by the agent.
# Authorization comes from a machine-readable local review receipt, not audit
# Markdown. This remains a workflow-integrity control, not a cryptographic trust
# boundary; human PR approval and protected-branch checks are authoritative.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

. (Join-Path $Root '.cursor/tools/factory-security-common.ps1')

function Test-ChangedFilesForSecrets {
  param([string]$Base)
  . (Join-Path $Root '.cursor/hooks/security-secret-rules.ps1')
  $rules = Get-SecuritySecretRules
  $files = @(
    @(git -C $Root diff --name-only $Base --)
    @(git -C $Root ls-files --others --exclude-standard)
  ) | Sort-Object -Unique
  $hits = @()
  foreach ($relative in $files) {
    $normalized = $relative -replace '\\', '/'
    if ($normalized -match '(^|/)(node_modules|vendor|dist|build|coverage|out|target|\.git)(/|$)' -or
        $normalized -match '^\.cursor/(hooks/state|prompt-log)/' -or
        $normalized -match '^docs/screenshots/' -or
        $normalized -match '\.(png|jpe?g|gif|webp|pdf|zip|lock|map)$') {
      continue
    }
    $path = Join-Path $Root $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $item = Get-Item -LiteralPath $path
    if ($item.Length -gt 1MB) { continue }
    $line = 0
    foreach ($text in @(Get-Content -LiteralPath $path -Encoding utf8)) {
      $line++
      foreach ($rule in $rules) {
        if ([string]$text -match $rule.Pattern) {
          $hits += "$($rule.Name) at $relative`:$line"
        }
      }
    }
  }
  return @($hits)
}

try {
  $context = Get-FactoryBranchContext -Root $Root
  $branch = $context.branch
  $issue = $context.issue
  $base = $context.base
  $diffHash = $context.diff_hash
  $secretHits = @(Test-ChangedFilesForSecrets -Base $base)

  $reviewPassed = $false
  $evidenceReason = 'machine-readable security-review receipt missing'
  $receiptPath = Join-Path $Root ".cursor/hooks/state/security-reviews/issue-$issue.json"
  $receipt = $null
  if (Test-Path -LiteralPath $receiptPath -PathType Leaf) {
    try {
      $receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding utf8 |
        ConvertFrom-Json
      $validSchema = [int]$receipt.schema_version -eq 1 -and
        [string]$receipt.source -eq 'cursor-security-review' -and
        [string]$receipt.review_id -match '^[A-Za-z0-9-]{8,}$'
      $matchesDiff = [string]$receipt.issue -eq [string]$issue -and
        [string]$receipt.branch -eq [string]$branch -and
        [string]$receipt.diff_hash -eq [string]$diffHash
      $passedResult = [string]$receipt.result -eq 'Passed' -and
        [int]$receipt.blocking_findings -eq 0
      $reviewPassed = $validSchema -and $matchesDiff -and $passedResult
      if (-not $reviewPassed) {
        $evidenceReason = 'security-review receipt is invalid, blocked, or stale'
      }
    } catch {
      $evidenceReason = 'security-review receipt is unreadable'
    }
  }
  if ($secretHits.Count) { $evidenceReason = 'potential secret material detected' }

  $status = if ($reviewPassed -and -not $secretHits.Count) { 'passed' } else { 'blocked' }
  $state = [ordered]@{
    issue = $issue
    branch = $branch
    diff_hash = $diffHash
    status = $status
    review_id = if ($receipt) { [string]$receipt.review_id } else { $null }
    review_receipt = if ($receipt) { ".cursor/hooks/state/security-reviews/issue-$issue.json" } else { $null }
    reason = if ($status -eq 'passed') { 'review receipt matches current diff' } else { $evidenceReason }
    secret_findings = @($secretHits)
    checked_at = [DateTime]::UtcNow.ToString('o')
  }
  $stateDir = Join-Path $Root '.cursor/hooks/state'
  $null = New-Item -ItemType Directory -Force -Path $stateDir
  $state | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $stateDir 'loop-security.json') -Encoding utf8
  if ($Json) { $state | ConvertTo-Json -Depth 5 } else {
    "$status`: issue $issue, diff $diffHash, $($state.reason)"
    foreach ($hit in $secretHits) { $hit }
  }
  if ($status -ne 'passed') { exit 2 }
} catch {
  $state = [ordered]@{
    status = 'blocked'
    reason = $_.Exception.Message
    checked_at = [DateTime]::UtcNow.ToString('o')
  }
  if ($Json) { $state | ConvertTo-Json } else { "blocked: $($state.reason)" }
  exit 2
}
