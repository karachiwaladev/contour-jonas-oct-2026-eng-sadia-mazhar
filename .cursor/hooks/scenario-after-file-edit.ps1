# Cursor afterFileEdit: classify edited paths for scenario-document follow-up.
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
  $category = Get-ScenarioPathCategory -Path ([string]$payload.file_path) -Root $root
  if ($category -eq 'irrelevant') {
    Write-Output '{}'
    exit 0
  }

  $statePath = Get-ScenarioStatePath -Root $root -ConversationId ([string]$payload.conversation_id)
  $state = Read-ScenarioState -Path $statePath `
    -ConversationId ([string]$payload.conversation_id) `
    -GenerationId ([string]$payload.generation_id) `
    -ResetForGeneration

  $absolutePath = [IO.Path]::GetFullPath([string]$payload.file_path)
  Add-ScenarioStatePath -State $state -Category $category -Path $absolutePath

  if ($category -eq 'application') {
    $state.blocked = $true
    $state.blocked_reason = 'Application code changed; scenario documentation review is pending.'
  }

  Write-ScenarioState -Path $statePath -State $state
} catch {
  # Post-edit reminders fail open; never disrupt a completed file edit.
}

Write-Output '{}'
exit 0
