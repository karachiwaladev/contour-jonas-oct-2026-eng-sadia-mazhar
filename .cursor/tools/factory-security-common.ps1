function Get-FactoryDiffHash {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Base
  )

  $tracked = @(git -C $Root diff --name-only $Base -- . `
    ':(exclude)docs/security/audits/*' 2>$null)
  if ($LASTEXITCODE -ne 0) { throw 'Could not compute branch diff.' }

  $untracked = @(git -C $Root ls-files --others --exclude-standard)
  $paths = @($tracked + $untracked) |
    Where-Object {
      -not [string]::IsNullOrWhiteSpace($_) -and
      ($_ -replace '\\', '/') -notmatch '^docs/security/audits/'
    } |
    Sort-Object -Unique
  $parts = [Collections.Generic.List[string]]::new()
  foreach ($relative in $paths) {
    $path = Join-Path $Root $relative
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $hash = (git -C $Root hash-object -- $relative 2>$null)
      $parts.Add("file:$($relative -replace '\\', '/')`:$hash")
    } else {
      $parts.Add("deleted:$($relative -replace '\\', '/')")
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

function Get-FactoryBranchContext {
  param([Parameter(Mandatory = $true)][string]$Root)

  $branch = (git -C $Root rev-parse --abbrev-ref HEAD 2>$null).Trim()
  if ($branch -notmatch '^factory/issue-(\d+)-[A-Za-z0-9][A-Za-z0-9._-]*$') {
    throw 'Current branch is not factory/issue-<n>-<slug>.'
  }
  $issue = $Matches[1]
  $default = (git -C $Root symbolic-ref refs/remotes/origin/HEAD 2>$null) `
    -replace '^refs/remotes/origin/', ''
  if ([string]::IsNullOrWhiteSpace($default)) { $default = 'main' }
  $base = "origin/$default"

  return [ordered]@{
    branch = $branch
    issue = $issue
    base = $base
    diff_hash = Get-FactoryDiffHash -Root $Root -Base $base
  }
}
