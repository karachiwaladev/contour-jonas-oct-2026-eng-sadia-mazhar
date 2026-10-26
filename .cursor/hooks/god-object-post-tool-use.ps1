# Cursor postToolUse: emit queued growth and approved-scope advisories.
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
  $config = Read-GodObjectConfig -Root $root
  $statePath = Get-GodObjectStatePath -Root $root `
    -ConversationId ([string]$payload.conversation_id)
  $state = Read-GodObjectState -Path $statePath `
    -ConversationId ([string]$payload.conversation_id) `
    -GenerationId ([string]$payload.generation_id) `
    -ResetForGeneration

  $scope = Read-GodObjectScope -Root $root
  $toolPath = Get-GodObjectToolPath -Payload $payload
  $relative = Get-GodObjectRelativePath -Path $toolPath -Root $root
  if ($config -and $scope -and [string]$scope.mode -eq 'implementation' -and
      $relative -and
      -not (Test-GodObjectExcluded -RelativePath $relative -Config $config) -and
      -not (Test-GodObjectApproved -RelativePath $relative -Scope $scope) -and
      $relative -notin @($state.scope_warned)) {
    Add-GodObjectPendingMessage -State $state -Message `
      "Scope guard: $relative is outside the approved paths for '$([string]$scope.ticket)'. The edit was allowed; confirm it is necessary and add a documented exception or revert it before completion."
    $state.scope_warned = @($state.scope_warned + $relative)
  }

  $messages = @($state.pending_messages)
  $state.pending_messages = @()
  Write-GodObjectState -Path $statePath -State $state

  if ($messages.Count -gt 0) {
    Write-Output (@{
        additional_context = ($messages -join "`n")
      } | ConvertTo-Json -Compress)
    exit 0
  }
} catch {
  # Advisory feedback fails open.
}

Write-Output '{}'
exit 0
