param(
  [string] $Root = (Get-Location).Path,
  [string[]] $Path,
  [switch] $Json
)

$ErrorActionPreference = 'Stop'
$errors = [Collections.Generic.List[string]]::new()
$checked = [Collections.Generic.List[string]]::new()

function Add-Problem {
  param([string] $File, [string] $Message)
  $errors.Add("$File`: $Message")
}

function Get-Field {
  param([string] $Content, [string] $Name)
  $match = [regex]::Match(
    $Content,
    "(?im)^\s*-\s*" + [regex]::Escape($Name) + "\s*:\s*(.*?)\s*$"
  )
  if ($match.Success) { return $match.Groups[1].Value.Trim() }
  return $null
}

function Test-RealValue {
  param([AllowNull()][string] $Value)
  return -not [string]::IsNullOrWhiteSpace($Value) -and
    $Value -notmatch '^<.*>$'
}

function Test-AuditDocument {
  param([string] $File, [string] $Content)
  foreach ($field in @(
      'Audit ID', 'Date', 'Owner', 'Authorized repository/ref',
      'Included paths/assets', 'Exclusions', 'Time limit', 'Cost cap',
      'External targets authorized'
    )) {
    if (-not (Test-RealValue (Get-Field $Content $field))) {
      Add-Problem $File "missing or placeholder field '$field'"
    }
  }

  foreach ($heading in @(
      'Security boundaries affected', 'Checks and evidence', 'Findings',
      'Completion review', 'Outcome and limitations'
    )) {
    if ($Content -notmatch "(?im)^##\s+" + [regex]::Escape($heading) + "\s*$") {
      Add-Problem $File "missing section '$heading'"
    }
  }

  $checksMatch = [regex]::Match(
    $Content,
    '(?ms)^##\s+Checks and evidence\s*$\s*(.*?)(?=^##\s+|\z)'
  )
  $checksSection = if ($checksMatch.Success) {
    $checksMatch.Groups[1].Value
  } else {
    ''
  }
  $rows = @([regex]::Matches(
      $checksSection,
      '(?m)^\|\s*([^|\r\n]+)\s*\|\s*([^|\r\n]*)\s*\|\s*(Run|Not run|Failed|Blocked)\s*\|'
    ))
  $dataRows = @($rows | Where-Object {
      $_.Groups[1].Value.Trim() -notin @('Check', '---')
    })
  if ($dataRows.Count -eq 0) {
    Add-Problem $File 'checks table has no row with an allowed status'
  }
  $statusLikeRows = @([regex]::Matches(
      $checksSection,
      '(?m)^\|\s*[^|\r\n]+\s*\|\s*[^|\r\n]*\s*\|\s*([^|\r\n]+)\s*\|'
    ))
  foreach ($row in $statusLikeRows) {
    $status = $row.Groups[1].Value.Trim()
    if ($status -notin @('Status', '---', 'Run', 'Not run', 'Failed', 'Blocked')) {
      Add-Problem $File "unsupported check status '$status'"
    }
  }

  $unchecked = [regex]::Matches($Content, '(?m)^\s*-\s*\[\s\]\s+').Count
  if ($unchecked -gt 0) {
    Add-Problem $File "$unchecked completion-review item(s) remain unchecked"
  }
  foreach ($field in @(
      'Actual cost', 'Checks run', 'Checks not run/failed', 'Unresolved risk',
      'Follow-up owner/date', 'Manual approval'
    )) {
    if (-not (Test-RealValue (Get-Field $Content $field))) {
      Add-Problem $File "missing or placeholder outcome '$field'"
    }
  }
}

function Test-FindingDocument {
  param([string] $File, [string] $Content)
  if ($Content -notmatch '(?m)^#\s+SEC-\d+\s*:\s*\S') {
    Add-Problem $File 'heading must use a stable SEC-<number> ID and title'
  }
  foreach ($field in @(
      'Severity', 'Confidence', 'Status', 'First observed', 'Last validated',
      'Audit/reference', 'Entry point', 'Affected asset',
      'Affected files/lines', 'Execution/data-flow trace',
      'Trust boundary crossed', 'Root cause', 'Safe evidence',
      'Attacker privileges', 'Preconditions', 'Exposure', 'Impact',
      'Smallest proposed fix', 'Regression test', 'Safe verification steps',
      'Verification status', 'Actual result/evidence', 'Remaining risk'
    )) {
    if (-not (Test-RealValue (Get-Field $Content $field))) {
      Add-Problem $File "missing or placeholder field '$field'"
    }
  }
  $verification = Get-Field $Content 'Verification status'
  if ((Test-RealValue $verification) -and
      $verification -notin @('Not run', 'Passed', 'Failed', 'Blocked')) {
    Add-Problem $File "unsupported verification status '$verification'"
  }
}

try {
  $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
  $rootPrefix = $rootFull + [IO.Path]::DirectorySeparatorChar
  $files = @()
  if ($Path -and $Path.Count) {
    foreach ($candidate in $Path) {
      $absolute = if ([IO.Path]::IsPathRooted($candidate)) {
        [IO.Path]::GetFullPath($candidate)
      } else {
        [IO.Path]::GetFullPath((Join-Path $rootFull $candidate))
      }
      if (-not $absolute.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $errors.Add("$candidate`: path is outside the repository")
      } elseif (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
        $errors.Add("$candidate`: file does not exist")
      } else {
        $files += $absolute
      }
    }
  } else {
    $auditDir = Join-Path $rootFull 'docs/security/audits'
    $findingDir = Join-Path $rootFull 'docs/security/findings'
    if (Test-Path -LiteralPath $auditDir) {
      $files += @(Get-ChildItem -LiteralPath $auditDir -Filter '*.md' -File)
    }
    if (Test-Path -LiteralPath $findingDir) {
      $files += @(Get-ChildItem -LiteralPath $findingDir -Filter 'SEC-*.md' -File)
    }
  }

  foreach ($item in $files) {
    $absolute = if ($item -is [IO.FileInfo]) { $item.FullName } else { [string]$item }
    $relative = $absolute.Substring($rootFull.Length).TrimStart('\', '/') -replace '\\', '/'
    $checked.Add($relative)
    $content = Get-Content -LiteralPath $absolute -Raw -Encoding utf8
    if ($content -match '(?m)^#\s+Security audit:') {
      Test-AuditDocument $relative $content
    } elseif ($content -match '(?m)^#\s+SEC-') {
      Test-FindingDocument $relative $content
    } else {
      Add-Problem $relative 'document is neither a security audit nor a finding'
    }
  }
} catch {
  $errors.Add("validator failure: $($_.Exception.Message)")
}

$result = [ordered]@{
  valid = ($errors.Count -eq 0)
  files_checked = @($checked)
  errors = @($errors)
}
if ($Json) {
  Write-Output ($result | ConvertTo-Json -Depth 5 -Compress)
} else {
  if ($result.valid) {
    Write-Output "Security audit validation passed ($($checked.Count) file(s))."
  } else {
    Write-Output "Security audit validation failed:"
    $errors | ForEach-Object { Write-Output " - $_" }
  }
}
if ($result.valid) { exit 0 } else { exit 1 }
