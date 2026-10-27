param(
  [string]$Root = (Get-Location).Path,
  [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z0-9-]{8,}$')]
  [string]$ReviewId,
  [Parameter(Mandatory = $true)][ValidateSet('Passed', 'Blocked')]
  [string]$Result,
  [Parameter(Mandatory = $true)][ValidateRange(0, 1000)]
  [int]$BlockingFindings,
  [ValidateRange(0, 1000)][int]$NonBlockingFindings = 0
)

# Machine-readable review receipt. Markdown audit files remain reporting only.
# This is a local workflow-integrity control, not cryptographic attestation:
# the developer/agent OS principal can modify local files and hooks.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

. (Join-Path $Root '.cursor/tools/factory-security-common.ps1')
$context = Get-FactoryBranchContext -Root $Root

if ($Result -eq 'Passed' -and $BlockingFindings -ne 0) {
  throw 'A passing review receipt cannot contain blocking findings.'
}
if ($Result -eq 'Blocked' -and $BlockingFindings -eq 0) {
  throw 'A blocked review receipt must contain at least one blocking finding.'
}

$receipt = [ordered]@{
  schema_version = 1
  source = 'cursor-security-review'
  review_id = $ReviewId
  issue = $context.issue
  branch = $context.branch
  base = $context.base
  diff_hash = $context.diff_hash
  result = $Result
  blocking_findings = $BlockingFindings
  non_blocking_findings = $NonBlockingFindings
  recorded_at = [DateTime]::UtcNow.ToString('o')
}

$stateDir = Join-Path $Root '.cursor/hooks/state/security-reviews'
$null = New-Item -ItemType Directory -Force -Path $stateDir
$path = Join-Path $stateDir "issue-$($context.issue).json"
$receipt | ConvertTo-Json -Depth 5 |
  Set-Content -LiteralPath $path -Encoding utf8
$receipt | ConvertTo-Json -Depth 5
