# Cursor stop: request one focused follow-up for missing scenario documentation.
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
  if ([string]$payload.status -ne 'completed') {
    Write-Output '{}'
    exit 0
  }

  . (Join-Path $PSScriptRoot 'scenario-hook-common.ps1')
  $root = Get-ScenarioWorkspaceRoot -Payload $payload
  $statePath = Get-ScenarioStatePath -Root $root -ConversationId ([string]$payload.conversation_id)
  $state = Read-ScenarioState -Path $statePath `
    -ConversationId ([string]$payload.conversation_id) `
    -GenerationId ([string]$payload.generation_id)

  if (@($state.application_files).Count -eq 0) {
    Write-Output '{}'
    exit 0
  }

  $validator = Join-Path $root '.cursor/tools/validate-test-scenarios.ps1'
  $validation = $null
  if (Test-Path $validator) {
    $validationRaw = & powershell -NoProfile -ExecutionPolicy Bypass `
      -File $validator -Root $root -Json 2>$null
    try { $validation = ($validationRaw -join "`n") | ConvertFrom-Json } catch { $validation = $null }
  }

  $scenarioUpdated = @($state.scenario_files).Count -gt 0
  $valid = $validation -and [bool]$validation.valid
  $state.blocked = -not ($scenarioUpdated -and $valid)

  if (-not $scenarioUpdated) {
    $state.blocked_reason = 'Application code changed, but no test scenario document was updated.'
  } elseif (-not $valid) {
    $details = if ($validation -and $validation.errors) {
      "$(@($validation.errors).Count) structural error(s)"
    } else {
      'validator execution could not be confirmed'
    }
    $state.blocked_reason = "Test scenario validation failed ($details)."
  } else {
    $state.blocked_reason = $null
  }

  $loopCount = if ($null -ne $payload.loop_count) { [int]$payload.loop_count } else { 0 }
  if ($state.blocked -and $loopCount -eq 0 -and -not $state.followup_sent) {
    $state.followup_sent = $true
    Write-ScenarioState -Path $statePath -State $state
    $message = "$($state.blocked_reason) Before delivery, inspect the acceptance criteria, create or update the relevant docs/test-scenarios/<feature>.md, run .cursor/tools/validate-test-scenarios.ps1, and keep unexecuted scenarios Planned."
    Write-Output (@{ followup_message = $message } | ConvertTo-Json -Compress)
    exit 0
  }

  Write-ScenarioState -Path $statePath -State $state
} catch {
  # Stop validation fails open; the factory commit hook also checks blocked state.
}

Write-Output '{}'
exit 0
