function Get-GodObjectWorkspaceRoot {
  param([object] $Payload)

  if ($Payload -and $Payload.workspace_roots -and $Payload.workspace_roots.Count -gt 0) {
    return [IO.Path]::GetFullPath([string]$Payload.workspace_roots[0])
  }
  return [IO.Path]::GetFullPath((Get-Location).Path)
}

function Get-GodObjectSafeId {
  param([string] $ConversationId)

  if ([string]::IsNullOrWhiteSpace($ConversationId)) { return 'unknown' }
  return ($ConversationId -replace '[^\w\-]', '_')
}

function Get-GodObjectStatePath {
  param([string] $Root, [string] $ConversationId)

  $stateDir = Join-Path $Root '.cursor/hooks/state'
  $null = New-Item -ItemType Directory -Force -Path $stateDir
  $safeId = Get-GodObjectSafeId -ConversationId $ConversationId
  return Join-Path $stateDir "$safeId.god-object.json"
}

function Get-GodObjectScopePath {
  param([string] $Root)
  return Join-Path $Root '.cursor/hooks/state/god-object-active-scope.json'
}

function New-GodObjectState {
  param([string] $ConversationId, [string] $GenerationId)

  return [ordered]@{
    conversation_id          = $ConversationId
    generation_id            = $GenerationId
    baselines                = [ordered]@{}
    growth_warned            = @()
    scope_warned             = @()
    scope_ticket             = ''
    pending_messages         = @()
    last_response            = ''
    completion_followup_sent = $false
    completion_ticket        = ''
    updated_at               = (Get-Date).ToUniversalTime().ToString('o')
  }
}

function ConvertTo-GodObjectMap {
  param([object] $Value)

  $map = [ordered]@{}
  if ($Value) {
    foreach ($property in $Value.PSObject.Properties) {
      $map[$property.Name] = $property.Value
    }
  }
  return $map
}

function Read-GodObjectState {
  param(
    [string] $Path,
    [string] $ConversationId,
    [string] $GenerationId,
    [switch] $ResetForGeneration
  )

  $state = $null
  if (Test-Path -LiteralPath $Path) {
    try {
      $state = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
    } catch {
      $state = $null
    }
  }

  if (-not $state) {
    return New-GodObjectState -ConversationId $ConversationId -GenerationId $GenerationId
  }

  $result = [ordered]@{
    conversation_id          = [string]$state.conversation_id
    generation_id            = [string]$state.generation_id
    baselines                = ConvertTo-GodObjectMap -Value $state.baselines
    growth_warned            = @($state.growth_warned)
    scope_warned             = @($state.scope_warned)
    scope_ticket             = [string]$state.scope_ticket
    pending_messages         = @($state.pending_messages)
    last_response            = [string]$state.last_response
    completion_followup_sent = [bool]$state.completion_followup_sent
    completion_ticket        = [string]$state.completion_ticket
    updated_at               = [string]$state.updated_at
  }

  if ($ResetForGeneration -and [string]$state.generation_id -ne $GenerationId) {
    $result.generation_id = $GenerationId
    $result.last_response = ''
  }

  return $result
}

function Write-GodObjectState {
  param([string] $Path, [object] $State)

  $State.updated_at = (Get-Date).ToUniversalTime().ToString('o')
  $State | ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $Path -Encoding utf8
}

function Read-GodObjectConfig {
  param([string] $Root)

  $path = Join-Path $Root '.cursor/god-object-management.json'
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  try {
    return Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Read-GodObjectScope {
  param([string] $Root)

  $path = Get-GodObjectScopePath -Root $Root
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  try {
    $scope = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
    if ([int]$scope.version -ne 1) { return $null }
    return $scope
  } catch {
    return $null
  }
}

function Get-GodObjectRelativePath {
  param([string] $Path, [string] $Root)

  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  try {
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $candidate = if ([IO.Path]::IsPathRooted($Path)) {
      [IO.Path]::GetFullPath($Path)
    } else {
      [IO.Path]::GetFullPath((Join-Path $rootFull $Path))
    }
    $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
      return $null
    }
    return $candidate.Substring($prefix.Length).Replace('\', '/')
  } catch {
    return $null
  }
}

function Test-GodObjectPathPrefix {
  param([string] $RelativePath, [string] $ConfiguredPath)

  $configured = ([string]$ConfiguredPath).Replace('\', '/').TrimStart('/')
  if ([string]::IsNullOrWhiteSpace($configured)) { return $false }
  if ($configured.EndsWith('/')) {
    return $RelativePath.StartsWith($configured, [StringComparison]::OrdinalIgnoreCase)
  }
  return $RelativePath.Equals($configured, [StringComparison]::OrdinalIgnoreCase)
}

function Test-GodObjectExcluded {
  param([string] $RelativePath, [object] $Config)

  foreach ($path in @($Config.excludedPaths)) {
    if (Test-GodObjectPathPrefix -RelativePath $RelativePath -ConfiguredPath ([string]$path)) {
      return $true
    }
  }
  return $false
}

function Test-GodObjectCandidate {
  param([string] $RelativePath, [object] $Config, [object] $Scope)

  foreach ($path in @($Config.candidateFiles) + @($Scope.candidate_paths)) {
    if (Test-GodObjectPathPrefix -RelativePath $RelativePath -ConfiguredPath ([string]$path)) {
      return $true
    }
  }
  return $false
}

function Test-GodObjectApproved {
  param([string] $RelativePath, [object] $Scope)

  if (-not $Scope) { return $true }
  foreach ($path in @($Scope.approved_paths)) {
    if (Test-GodObjectPathPrefix -RelativePath $RelativePath -ConfiguredPath ([string]$path)) {
      return $true
    }
  }
  foreach ($exception in @($Scope.exceptions)) {
    if ($exception -and
        (Test-GodObjectPathPrefix -RelativePath $RelativePath -ConfiguredPath ([string]$exception.path))) {
      return $true
    }
  }
  return $false
}

function Get-GodObjectToolPath {
  param([object] $Payload)

  if (-not $Payload -or -not $Payload.tool_input) { return $null }
  foreach ($name in @('path', 'file_path', 'target_file')) {
    $property = $Payload.tool_input.PSObject.Properties[$name]
    if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
      return [string]$property.Value
    }
  }
  return $null
}

function Get-GodObjectLineCount {
  param([string] $Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 0 }
  return [IO.File]::ReadAllLines($Path).Count
}

function Get-GodObjectGitBaseline {
  param([string] $Root, [string] $RelativePath)

  try {
    $content = @(& git -C $Root show ("HEAD:" + $RelativePath) 2>$null)
    if ($LASTEXITCODE -eq 0) { return [int]$content.Count }
  } catch {
  }
  return $null
}

function Get-GodObjectEditDelta {
  param([object] $Edits)

  $delta = 0
  foreach ($edit in @($Edits)) {
    $oldCount = if ([string]::IsNullOrEmpty([string]$edit.old_string)) {
      0
    } else {
      ([string]$edit.old_string -split "`r?`n").Count
    }
    $newCount = if ([string]::IsNullOrEmpty([string]$edit.new_string)) {
      0
    } else {
      ([string]$edit.new_string -split "`r?`n").Count
    }
    $delta += ($newCount - $oldCount)
  }
  return $delta
}

function Test-GodObjectSubstantialGrowth {
  param([int] $Baseline, [int] $Current, [object] $Growth)

  $added = $Current - $Baseline
  if ($added -lt 1) { return $false }
  if ($added -ge [int]$Growth.substantialAddedLines) { return $true }
  if ($Baseline -lt [int]$Growth.minimumBaselineLines -or
      $added -lt [int]$Growth.minimumPercentageAddedLines) {
    return $false
  }
  return (($added * 100.0 / $Baseline) -ge [double]$Growth.percentageOfBaseline)
}

function Add-GodObjectPendingMessage {
  param([object] $State, [string] $Message)

  if ($Message -notin @($State.pending_messages)) {
    $State.pending_messages = @($State.pending_messages + $Message)
  }
}
