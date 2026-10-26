param(
  [string] $Root = (Get-Location).Path,
  [string[]] $Path,
  [switch] $Json
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

$allowedStatuses = @('Planned', 'Automated', 'Passed', 'Failed', 'Blocked')
$errors = [Collections.Generic.List[string]]::new()
$results = [Collections.Generic.List[object]]::new()
$allIds = @{}

function Add-ValidationError {
  param(
    [string] $File,
    [int] $Line,
    [string] $Message
  )

  $location = if ($Line -gt 0) { "${File}:$Line" } else { $File }
  $errors.Add("${location}: $Message")
}

function Test-MeaningfulValue {
  param([string] $Value)

  if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
  $trimmed = $Value.Trim()
  return $trimmed -notmatch '^(TBD|<required>)$' -and
    $trimmed -match '[\p{L}\p{N}]'
}

$rootPath = [IO.Path]::GetFullPath($Root)
$scenarioRoot = Join-Path $rootPath 'docs/test-scenarios'

if ($Path -and $Path.Count -gt 0) {
  $files = foreach ($item in $Path) {
    $candidate = if ([IO.Path]::IsPathRooted($item)) { $item } else { Join-Path $rootPath $item }
    if (Test-Path $candidate -PathType Leaf) {
      Get-Item $candidate
    } else {
      Add-ValidationError -File $item -Line 0 -Message 'File does not exist.'
    }
  }
} elseif (Test-Path $scenarioRoot) {
  $files = Get-ChildItem -Path $scenarioRoot -File -Filter '*.md' |
    Where-Object { -not $_.Name.StartsWith('_') }
} else {
  $files = @()
}

$files = @($files)
if ($files.Count -eq 0) {
  Add-ValidationError -File 'docs/test-scenarios' -Line 0 -Message 'No scenario documents found.'
}

foreach ($file in $files) {
  $filePath = [IO.Path]::GetFullPath($file.FullName)
  $relative = if ($filePath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) {
    $filePath.Substring($rootPath.TrimEnd('\', '/').Length).TrimStart('\', '/') -replace '\\', '/'
  } else {
    $file.Name
  }
  $lines = @(Get-Content -Path $file.FullName -Encoding utf8)
  $content = $lines -join "`n"
  $fileErrorsBefore = $errors.Count
  $scenarioCount = 0

  foreach ($heading in @(
      'Feature and scope',
      'Requirements and acceptance criteria',
      'Preconditions and test data',
      'Scenarios',
      'Assumptions / open questions'
    )) {
    if ($content -notmatch "(?m)^##\s+$([regex]::Escape($heading))\s*$") {
      Add-ValidationError -File $relative -Line 0 -Message "Missing section: ## $heading"
    }
  }

  $headerPattern = '^\|\s*ID\s*\|\s*Scenario\s*\|\s*Preconditions\s*\|\s*Steps\s*/\s*input\s*\|\s*Expected result\s*\|\s*Type\s*\|\s*Status\s*\|\s*Evidence\s*\|$'
  if (-not ($lines | Where-Object { $_ -match $headerPattern })) {
    Add-ValidationError -File $relative -Line 0 -Message 'Missing the required eight-column scenario table header.'
  }

  $scenarioRows = [Collections.Generic.List[string]]::new()
  for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = $lines[$index]
    if ($line -notmatch '^\s*\|') { continue }
    if ($line -match $headerPattern -or $line -match '^\s*\|\s*:?-{3,}') { continue }

    $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -ne 8) {
      Add-ValidationError -File $relative -Line ($index + 1) -Message "Expected 8 table fields; found $($cells.Count)."
      continue
    }

    $id, $description, $preconditions, $steps, $expected, $type, $status, $evidence = $cells
    if ($id -notmatch '^[A-Z][A-Z0-9-]*-\d{3}$') {
      Add-ValidationError -File $relative -Line ($index + 1) -Message "Invalid scenario ID '$id'; expected <AREA>-<NNN>."
    } elseif ($allIds.ContainsKey($id)) {
      Add-ValidationError -File $relative -Line ($index + 1) -Message "Duplicate scenario ID '$id' (first seen at $($allIds[$id]))."
    } else {
      $allIds[$id] = "${relative}:$($index + 1)"
    }

    foreach ($field in @(
        @{ Name = 'Scenario description'; Value = $description },
        @{ Name = 'Preconditions'; Value = $preconditions },
        @{ Name = 'Steps / input'; Value = $steps },
        @{ Name = 'Expected result'; Value = $expected },
        @{ Name = 'Test type'; Value = $type }
      )) {
      if (-not (Test-MeaningfulValue -Value ([string]$field.Value))) {
        Add-ValidationError -File $relative -Line ($index + 1) -Message "$($field.Name) is required."
      }
    }

    if ($status -notin $allowedStatuses) {
      Add-ValidationError -File $relative -Line ($index + 1) -Message "Invalid status '$status'."
    }
    if ($status -in @('Passed', 'Failed', 'Blocked') -and
        -not (Test-MeaningfulValue -Value $evidence)) {
      Add-ValidationError -File $relative -Line ($index + 1) -Message "$status requires evidence or a blocker reference."
    }

    $scenarioRows.Add($line)
    $scenarioCount++
  }

  if ($scenarioCount -eq 0) {
    Add-ValidationError -File $relative -Line 0 -Message 'No scenario rows found.'
  }

  $requirements = [regex]::Matches($content, '\*\*(R[A-Z0-9-]*\d+):\*\*') |
    ForEach-Object { $_.Groups[1].Value } |
    Sort-Object -Unique
  $scenarioText = $scenarioRows -join "`n"
  foreach ($requirement in $requirements) {
    if ($scenarioText -notmatch "(?<![A-Z0-9-])$([regex]::Escape($requirement))(?![A-Z0-9-])") {
      Add-ValidationError -File $relative -Line 0 -Message "Requirement $requirement has no scenario traceability."
    }
  }

  $links = [regex]::Matches($content, '\[[^\]]+\]\((?!https?://|mailto:|#)([^)#]+)(?:#[^)]+)?\)')
  foreach ($link in $links) {
    $target = [Uri]::UnescapeDataString($link.Groups[1].Value)
    $resolved = [IO.Path]::GetFullPath((Join-Path $file.DirectoryName $target))
    $rootPrefix = $rootPath.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      Add-ValidationError -File $relative -Line 0 -Message "Evidence/reference link escapes the repository: $target"
    } elseif (-not (Test-Path $resolved)) {
      Add-ValidationError -File $relative -Line 0 -Message "Evidence/reference link does not resolve: $target"
    }
  }

  $results.Add([ordered]@{
      path = $relative
      valid = ($errors.Count -eq $fileErrorsBefore)
      scenarios = $scenarioCount
      requirements = @($requirements).Count
    })
}

$report = [ordered]@{
  valid = ($errors.Count -eq 0)
  files = @($results)
  errors = @($errors)
}

if ($Json) {
  Write-Output ($report | ConvertTo-Json -Compress -Depth 8)
} elseif ($report.valid) {
  Write-Output "PASS: $($results.Count) scenario document(s) validated."
  foreach ($result in $results) {
    Write-Output "  $($result.path): $($result.scenarios) scenarios, $($result.requirements) requirements"
  }
} else {
  Write-Output "FAIL: $($errors.Count) scenario documentation error(s)."
  foreach ($validationError in $errors) {
    Write-Output "  $validationError"
  }
}

if ($report.valid) { exit 0 } else { exit 1 }
