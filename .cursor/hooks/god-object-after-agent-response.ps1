# Cursor afterAgentResponse: retain the final report for deterministic stop checks.
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
  . (Join-Path $PSScriptRoot 'god-object-hook-common.ps1')

  $root = Get-GodObjectWorkspaceRoot -Payload $payload
  $statePath = Get-GodObjectStatePath -Root $root `
    -ConversationId ([string]$payload.conversation_id)
  $state = Read-GodObjectState -Path $statePath `
    -ConversationId ([string]$payload.conversation_id) `
    -GenerationId ([string]$payload.generation_id) `
    -ResetForGeneration
  $state.last_response = [string]$payload.text
  Write-GodObjectState -Path $statePath -State $state
} catch {
  # Completion-report capture is advisory and fails open.
}

Write-Output '{}'
exit 0
