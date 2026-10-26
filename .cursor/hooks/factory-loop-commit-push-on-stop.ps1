# Cursor stop/sessionEnd: safe commit + push when factory-loop left the repo dirty.
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

git push
if ($LASTEXITCODE -ne 0) {
  Write-FactoryLog @{ action = 'push_failed'; message = $msg }
  Write-Output '{}'
  exit 0
}

Write-FactoryLog @{ action = 'commit_push_ok'; message = $msg; files = ($staged -split "`n") }
Write-Output '{}'
exit 0
