param(
  [string]$Root = (Get-Location).Path,
  [Parameter(Mandatory = $true)][ValidatePattern('^\d+$')][string]$Issue,
  [Parameter(Mandatory = $true)]
  [ValidateSet('clarify', 'plan', 'approval', 'build', 'verify', 'bugbot', 'security-review', 'deliver', 'manual-review')]
  [string]$Stage,
  [Parameter(Mandatory = $true)][ValidateSet('advanced', 'blocked')]
  [string]$Result,
  [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
  [string]$Action,
  [string]$Blocker
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

if ($Result -eq 'blocked' -and [string]::IsNullOrWhiteSpace($Blocker)) {
  throw 'Blocked progress requires an exact blocker and required next action.'
}
if ($Result -eq 'advanced' -and -not [string]::IsNullOrWhiteSpace($Blocker)) {
  throw 'Advanced progress must not include a blocker.'
}

$state = [ordered]@{
  schema_version = 1
  issue = $Issue
  stage = $Stage
  result = $Result
  action = $Action
  blocker = if ($Result -eq 'blocked') { $Blocker } else { $null }
  recorded_at = [DateTime]::UtcNow.ToString('o')
}

$stateDir = Join-Path $Root '.cursor/hooks/state'
$null = New-Item -ItemType Directory -Force -Path $stateDir
$state | ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath (Join-Path $stateDir 'factory-loop-progress.json') -Encoding utf8

$tickStatePath = Join-Path $stateDir 'factory-loop-tick.json'
if (Test-Path -LiteralPath $tickStatePath -PathType Leaf) {
  try {
    $tick = Get-Content -LiteralPath $tickStatePath -Raw -Encoding utf8 |
      ConvertFrom-Json
    $completedTick = [ordered]@{
      schema_version = [int]$tick.schema_version
      tick_id = [string]$tick.tick_id
      purpose = [string]$tick.purpose
      status = 'completed'
      started_at = [string]$tick.started_at
      issue = $Issue
      stage = $Stage
      result = $Result
      action = $Action
      blocker = if ($Result -eq 'blocked') { $Blocker } else { $null }
      completed_at = [DateTime]::UtcNow.ToString('o')
    }
    $completedTick | ConvertTo-Json -Depth 5 |
      Set-Content -LiteralPath $tickStatePath -Encoding utf8
  } catch {
    throw 'Factory tick state is unreadable; progress was recorded but the tick cannot be closed.'
  }
}

$state | ConvertTo-Json -Depth 4
