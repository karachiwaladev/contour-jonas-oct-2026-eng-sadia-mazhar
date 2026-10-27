param(
  [string]$Root = (Get-Location).Path,
  [switch]$Json
)

# Deterministic local gate. Cursor security-review itself is run by the agent;
# this script binds its validated evidence to the exact current branch diff.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

function Get-DiffHash {
  param([string]$Base)
  $diff = @(git -C $Root diff --binary $Base -- . `
    ':(exclude)docs/security/audits/*' 2>$null)
  if ($LASTEXITCODE -ne 0) { throw 'Could not compute branch diff.' }
  $untracked = @(git -C $Root ls-files --others --exclude-standard)
  $parts = [Collections.Generic.List[string]]::new()
  $parts.Add(($diff -join "`n"))
  foreach ($relative in ($untracked | Sort-Object)) {
    if (($relative -replace '\\', '/') -match '^docs/security/audits/') { continue }
    $path = Join-Path $Root $relative
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $hash = (git -C $Root hash-object -- $relative 2>$null)
      $parts.Add("untracked:$relative`:$hash")
    }
  }
  $bytes = [Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

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
  $branch = (git -C $Root rev-parse --abbrev-ref HEAD 2>$null).Trim()
  if ($branch -notmatch '^factory/issue-(\d+)-') {
    throw 'Current branch is not factory/issue-<n>-<slug>.'
  }
  $issue = $Matches[1]
  $default = (git -C $Root symbolic-ref refs/remotes/origin/HEAD 2>$null) `
    -replace '^refs/remotes/origin/', ''
  if ([string]::IsNullOrWhiteSpace($default)) { $default = 'main' }
  $base = "origin/$default"
  $diffHash = Get-DiffHash -Base $base
  $secretHits = @(Test-ChangedFilesForSecrets -Base $base)

  $audit = Get-ChildItem -LiteralPath (Join-Path $Root 'docs/security/audits') `
    -Filter "*issue-$issue*.md" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

  $reviewPassed = $false
  $evidenceReason = 'security-review evidence missing'
  if ($audit) {
    $content = Get-Content -LiteralPath $audit.FullName -Raw -Encoding utf8
    $hasHash = $content -match "(?im)^\s*-\s*Diff hash\s*:\s*$([regex]::Escape($diffHash))\s*$"
    $hasResult = $content -match '(?im)^\s*-\s*Security-review result\s*:\s*Passed\s*$'
    $hasNoBlockers = $content -match '(?im)^\s*-\s*Blocking findings\s*:\s*0\s*$'
    if ($hasHash -and $hasResult -and $hasNoBlockers) {
      & powershell -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $Root '.cursor/tools/validate-security-audit.ps1') `
        -Root $Root -Path $audit.FullName *> $null
      $reviewPassed = $LASTEXITCODE -eq 0
      if (-not $reviewPassed) { $evidenceReason = 'security-review evidence failed validation' }
    } else {
      $evidenceReason = 'security-review evidence does not match current diff'
    }
  }
  if ($secretHits.Count) { $evidenceReason = 'potential secret material detected' }

  $status = if ($reviewPassed -and -not $secretHits.Count) { 'passed' } else { 'blocked' }
  $state = [ordered]@{
    issue = $issue
    branch = $branch
    diff_hash = $diffHash
    status = $status
    review_evidence = if ($audit) { $audit.FullName.Substring($Root.TrimEnd('\').Length + 1) } else { $null }
    reason = if ($status -eq 'passed') { 'validated evidence matches current diff' } else { $evidenceReason }
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
