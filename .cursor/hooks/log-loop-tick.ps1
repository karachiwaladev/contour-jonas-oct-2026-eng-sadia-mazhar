param(
  [Parameter(Mandatory = $true)]
  [string] $Prompt,
  [string] $Purpose = 'skill_factory_loop'
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/write-prompt-log.ps1"

$root = if ($env:CURSOR_WORKSPACE_ROOT) {
  $env:CURSOR_WORKSPACE_ROOT
} else {
  (Get-Location).Path
}
$stateDir = Join-Path $root '.cursor/hooks/state'
$null = New-Item -ItemType Directory -Force -Path $stateDir
$tickStatePath = Join-Path $stateDir 'factory-loop-tick.json'

if (Test-Path -LiteralPath $tickStatePath) {
  try {
    $previous = Get-Content -LiteralPath $tickStatePath -Raw -Encoding utf8 |
      ConvertFrom-Json
    if ([string]$previous.status -eq 'pending') {
      Write-PromptLog -Record @{
        event = 'loop_stalled'
        source = 'factory-loop'
        purpose = $Purpose
        tick_id = [string]$previous.tick_id
        reason = 'Previous tick recorded no material progress or exact blocker.'
      }
    }
  } catch {
    Write-PromptLog -Record @{
      event = 'loop_state_unreadable'
      source = 'factory-loop'
      purpose = $Purpose
    }
  }
}

$tick = [ordered]@{
  schema_version = 1
  tick_id = [guid]::NewGuid().ToString()
  purpose = $Purpose
  status = 'pending'
  started_at = [DateTime]::UtcNow.ToString('o')
}
$tick | ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath $tickStatePath -Encoding utf8

Write-PromptLog -Record @{
  event   = 'loop_tick'
  source  = 'factory-loop'
  purpose = $Purpose
  prompt  = $Prompt
  tick_id = $tick.tick_id
}
