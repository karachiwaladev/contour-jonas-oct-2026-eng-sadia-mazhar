function Get-ScenarioWorkspaceRoot {
  param([object] $Payload)

  if ($Payload -and $Payload.workspace_roots -and $Payload.workspace_roots.Count -gt 0) {
    return [string]$Payload.workspace_roots[0]
  }
  return (Get-Location).Path
}

function Get-ScenarioSafeId {
  param([string] $ConversationId)

  if ([string]::IsNullOrWhiteSpace($ConversationId)) {
    return 'unknown'
  }
  return ($ConversationId -replace '[^\w\-]', '_')
}

function Get-ScenarioStatePath {
  param(
    [string] $Root,
    [string] $ConversationId
  )

  $stateDir = Join-Path $Root '.cursor/hooks/state'
  $null = New-Item -ItemType Directory -Force -Path $stateDir
  $safeId = Get-ScenarioSafeId -ConversationId $ConversationId
  return Join-Path $stateDir "$safeId.scenario.json"
}

function New-ScenarioState {
  param(
    [string] $ConversationId,
    [string] $GenerationId
  )

  return [ordered]@{
    conversation_id  = $ConversationId
    generation_id    = $GenerationId
    application_files = @()
    test_files       = @()
    scenario_files   = @()
    reminder_sent    = $false
    followup_sent    = $false
    blocked          = $false
    blocked_reason   = $null
    updated_at       = (Get-Date).ToUniversalTime().ToString('o')
  }
}

function Read-ScenarioState {
  param(
    [string] $Path,
    [string] $ConversationId,
    [string] $GenerationId,
    [switch] $ResetForGeneration
  )

  $state = $null
  if (Test-Path $Path) {
    try {
      $state = Get-Content -Path $Path -Raw -Encoding utf8 | ConvertFrom-Json
    } catch {
      $state = $null
    }
  }

  if (-not $state -or ($ResetForGeneration -and $state.generation_id -ne $GenerationId)) {
    return New-ScenarioState -ConversationId $ConversationId -GenerationId $GenerationId
  }

  return [ordered]@{
    conversation_id  = [string]$state.conversation_id
    generation_id    = [string]$state.generation_id
    application_files = @($state.application_files)
    test_files       = @($state.test_files)
    scenario_files   = @($state.scenario_files)
    reminder_sent    = [bool]$state.reminder_sent
    followup_sent    = [bool]$state.followup_sent
    blocked          = [bool]$state.blocked
    blocked_reason   = $state.blocked_reason
    updated_at       = [string]$state.updated_at
  }
}

function Write-ScenarioState {
  param(
    [string] $Path,
    [object] $State
  )

  $State.updated_at = (Get-Date).ToUniversalTime().ToString('o')
  $State | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding utf8
}

function Add-ScenarioStatePath {
  param(
    [object] $State,
    [ValidateSet('application', 'test', 'scenario')]
    [string] $Category,
    [string] $Path
  )

  $property = "${Category}_files"
  $values = @($State[$property])
  if ($Path -notin $values) {
    $State[$property] = @($values + $Path)
  }
}

function Get-ScenarioPathCategory {
  param(
    [string] $Path,
    [string] $Root
  )

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return 'irrelevant'
  }

  try {
    $absolute = [IO.Path]::GetFullPath($Path)
    $rootAbsolute = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $rootPrefix = $rootAbsolute + [IO.Path]::DirectorySeparatorChar
    if (-not $absolute.Equals($rootAbsolute, [StringComparison]::OrdinalIgnoreCase) -and
        -not $absolute.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      return 'irrelevant'
    }
    $relative = $absolute.Substring($rootAbsolute.Length).TrimStart('\', '/')
  } catch {
    return 'irrelevant'
  }

  $normalized = ($relative -replace '\\', '/').ToLowerInvariant()
  if ($normalized -match '(^|/)(\.git|node_modules|vendor|dist|build|coverage|out|target|\.next|\.cache|\.tmp)(/|$)' -or
      $normalized -match '^\.cursor/(prompt-log|hooks/state)/' -or
      $normalized -match '^docs/screenshots/' -or
      $normalized -match '(\.min\.(js|css)|\.map|\.generated\.[^/]+)$') {
    return 'irrelevant'
  }

  if ($normalized -match '^docs/test-scenarios/.*\.md$') {
    return 'scenario'
  }

  if ($normalized -match '(^|/)(tests?|__tests__|specs?)(/|$)' -or
      $normalized -match '\.(test|spec)\.[^/]+$') {
    return 'test'
  }

  if ($normalized -match '^todo/.*\.(js|html|css)$' -or
      $normalized -match '^(src|app|lib|server|client)/.*\.(ts|tsx|js|jsx|py|cs|java|go|rs|vue|svelte|html|css|scss)$') {
    return 'application'
  }

  return 'irrelevant'
}
