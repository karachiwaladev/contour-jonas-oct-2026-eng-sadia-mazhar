# Cursor stop/sessionEnd: safe local commit when factory-loop left the repo
# dirty. Legacy filename retained for hook compatibility; this script never
# pushes.
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::UTF8
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

$raw = [Console]::In.ReadToEnd()
$payload = $null
if (-not [string]::IsNullOrWhiteSpace($raw)) {
  $payload = $raw | ConvertFrom-Json
}

$root = if ($payload -and $payload.workspace_roots -and $payload.workspace_roots.Count -gt 0) {
  $payload.workspace_roots[0]
} else {
  (Get-Location).Path
}

Set-Location $root

if (-not (Test-Path (Join-Path $root '.git'))) {
  Write-Output '{}'
  exit 0
}

$activeFlag = Join-Path $root '.cursor/factory-loop-active'
if (-not (Test-Path $activeFlag)) {
  Write-Output '{}'
  exit 0
}

function Write-FactoryLog($Record) {
  . (Join-Path $PSScriptRoot 'write-prompt-log.ps1')
  $Record['event'] = 'factory_git'
  Write-PromptLog -Record $Record
}

# Do not auto-commit feature work while its scenario review is unresolved.
if ($payload -and -not [string]::IsNullOrWhiteSpace([string]$payload.conversation_id)) {
  . (Join-Path $PSScriptRoot 'scenario-hook-common.ps1')
  $scenarioStatePath = Get-ScenarioStatePath -Root $root `
    -ConversationId ([string]$payload.conversation_id)
  if (Test-Path $scenarioStatePath) {
    try {
      $scenarioState = Get-Content -Path $scenarioStatePath -Raw -Encoding utf8 |
        ConvertFrom-Json
      if ([bool]$scenarioState.blocked -and @($scenarioState.application_files).Count -gt 0) {
        Write-FactoryLog @{
          action = 'skipped_scenario_documentation'
          reason = [string]$scenarioState.blocked_reason
        }
        Write-Output '{}'
        exit 0
      }
    } catch {
      Write-FactoryLog @{ action = 'scenario_state_unreadable'; message = $_.Exception.Message }
      Write-Output '{}'
      exit 0
    }
  }
}

$branch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
if ($branch -in @('main', 'master', 'HEAD')) {
  Write-FactoryLog @{ action = 'skipped_default_branch'; branch = $branch }
  Write-Output '{}'
  exit 0
}
if ($branch -notmatch '^factory/issue-\d+-[A-Za-z0-9][A-Za-z0-9._-]*$') {
  Write-FactoryLog @{ action = 'skipped_invalid_factory_branch'; branch = $branch }
  Write-Output '{}'
  exit 0
}

$expectedRepository = 'karachiwaladev/contour-jonas-oct-2026-eng-sadia-mazhar'
$origin = (git remote get-url origin 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or
    $origin -notmatch '(?i)(?:github\.com[/:])([^/:\s]+/[^/\s]+?)(?:\.git)?$' -or
    $Matches[1] -ne $expectedRepository) {
  Write-FactoryLog @{
    action = 'skipped_untrusted_origin'
    expected_repository = $expectedRepository
  }
  Write-Output '{}'
  exit 0
}

$porcelain = git status --porcelain 2>&1
if ([string]::IsNullOrWhiteSpace($porcelain)) {
  Write-Output '{}'
  exit 0
}

git add -A
git reset --quiet -- .cursor/prompt-log/ .cursor/hooks/state/ .tmp/ 2>$null

$staged = git diff --cached --name-only
if ([string]::IsNullOrWhiteSpace($staged)) {
  Write-Output '{}'
  exit 0
}

$status = if ($payload) { $payload.status } else { 'unknown' }
$msg = "factory-loop: deliver work on agent stop ($status)"

git commit -m $msg
if ($LASTEXITCODE -ne 0) {
  Write-FactoryLog @{ action = 'commit_failed'; message = $msg }
  Write-Output '{}'
  exit 0
}

$securityGate = Join-Path $root '.cursor/tools/check-loop-security.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $securityGate `
  -Root $root *> $null
if ($LASTEXITCODE -ne 0) {
  Write-FactoryLog @{
    action = 'push_deferred_security_review'
    message = $msg
    reason = 'security-review receipt missing, invalid, blocked, or stale'
  }
  Write-Output '{}'
  exit 0
}

Write-FactoryLog @{
  action = 'commit_ready_for_approved_push'
  message = $msg
  branch = $branch
  files = ($staged -split "`n")
}
Write-Output (@{
  followup_message = "Factory-loop committed reviewed changes on '$branch' but did not auto-push. Ask the user to approve the exact git push; the before-push hook will revalidate the current receipt and show the native approval gate."
} | ConvertTo-Json -Compress)
exit 0
