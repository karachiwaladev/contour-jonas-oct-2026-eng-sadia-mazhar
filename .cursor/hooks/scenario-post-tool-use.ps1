# Cursor postToolUse(Write): inject one scenario-document reminder per generation.
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::UTF8
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

try {
  $raw = [Console]::In.ReadToEnd()
  if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Output '{}'
    exit 0
  }

  $payload = $raw | ConvertFrom-Json
  . (Join-Path $PSScriptRoot 'scenario-hook-common.ps1')

  $root = Get-ScenarioWorkspaceRoot -Payload $payload
  $statePath = Get-ScenarioStatePath -Root $root -ConversationId ([string]$payload.conversation_id)
  $state = Read-ScenarioState -Path $statePath `
    -ConversationId ([string]$payload.conversation_id) `
    -GenerationId ([string]$payload.generation_id) `
    -ResetForGeneration

  # Fall back to tool_input when event ordering means afterFileEdit has not run.
  $toolInput = $payload.tool_input
  if ($toolInput -is [string] -and -not [string]::IsNullOrWhiteSpace($toolInput)) {
    try { $toolInput = $toolInput | ConvertFrom-Json } catch { $toolInput = $null }
  }
  $toolPath = if ($toolInput) {
    @($toolInput.path, $toolInput.file_path, $toolInput.target_file) |
      Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
      Select-Object -First 1
  } else {
    $null
  }

  if ($toolPath) {
    $category = Get-ScenarioPathCategory -Path ([string]$toolPath) -Root $root
    if ($category -ne 'irrelevant') {
      $absoluteToolPath = [IO.Path]::GetFullPath([string]$toolPath)
      Add-ScenarioStatePath -State $state -Category $category -Path $absoluteToolPath
      if ($category -eq 'application') {
        $state.blocked = $true
        $state.blocked_reason = 'Application code changed; scenario documentation review is pending.'
      }
      Write-ScenarioState -Path $statePath -State $state
    }
  }

  if (@($state.application_files).Count -gt 0 -and
      @($state.scenario_files).Count -eq 0 -and
      -not $state.reminder_sent) {
    $state.reminder_sent = $true
    Write-ScenarioState -Path $statePath -State $state
    $context = 'Feature code changed. Keep test scenarios alongside development: inspect acceptance criteria and create or update the relevant docs/test-scenarios/<feature>.md using the test-scenarios skill. Keep unexecuted cases Planned; record actual results only after testing.'
    Write-Output (@{ additional_context = $context } | ConvertTo-Json -Compress)
    exit 0
  }
} catch {
  # Reminder hooks fail open; stop validation remains the final local check.
}

Write-Output '{}'
exit 0
