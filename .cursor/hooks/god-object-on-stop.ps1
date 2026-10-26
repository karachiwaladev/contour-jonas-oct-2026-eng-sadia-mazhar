# Cursor stop: request one concise completion-report correction when required.
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

  . (Join-Path $PSScriptRoot 'god-object-hook-common.ps1')
  $root = Get-GodObjectWorkspaceRoot -Payload $payload
  $scope = Read-GodObjectScope -Root $root
  if (-not $scope -or [string]$scope.mode -ne 'implementation' -or
      [bool]$scope.intentionally_incomplete) {
    Write-Output '{}'
    exit 0
  }

  $statePath = Get-GodObjectStatePath -Root $root `
    -ConversationId ([string]$payload.conversation_id)
  $state = Read-GodObjectState -Path $statePath `
    -ConversationId ([string]$payload.conversation_id) `
    -GenerationId ([string]$payload.generation_id)
  $scopeTicket = [string]$scope.ticket
  if ([string]$state.completion_ticket -ne $scopeTicket) {
    $state.completion_followup_sent = $false
    $state.completion_ticket = $scopeTicket
  }
  $response = [string]$state.last_response
  $missing = @()

  if ($response -notmatch '(?im)^\s*(?:#+\s*)?(?:\*\*)?changed files') {
    $missing += 'changed files'
  }
  if ($response -notmatch '(?im)^\s*(?:#+\s*)?(?:\*\*)?(tests?|verification)') {
    $missing += 'tests and actual results'
  } elseif ($response -notmatch '(?is)(passed|failed|blocked|not run|not executed|n/a|exit code|manual)') {
    $missing += 'an explicit test outcome'
  }
  if ($response -notmatch '(?im)^\s*(?:#+\s*)?(?:\*\*)?architecture') {
    $missing += 'architecture decisions'
  }
  if ($response -notmatch '(?im)^\s*(?:#+\s*)?(?:\*\*)?unresolved') {
    $missing += 'unresolved issues or None'
  }

  if (@($state.scope_warned).Count -gt 0) {
    $unaddressed = @($state.scope_warned | Where-Object {
        $response -notmatch [regex]::Escape([string]$_)
      })
    if ($unaddressed.Count -gt 0) {
      $missing += "scope-warning disposition for $($unaddressed -join ', ')"
    }
  }

  $scenarioReason = $null
  $scenarioPath = Join-Path $root (
    ".cursor/hooks/state/{0}.scenario.json" -f
    (Get-GodObjectSafeId -ConversationId ([string]$payload.conversation_id))
  )
  if (Test-Path -LiteralPath $scenarioPath) {
    try {
      $scenario = Get-Content -LiteralPath $scenarioPath -Raw -Encoding utf8 |
        ConvertFrom-Json
      if ([bool]$scenario.blocked) {
        $scenarioReason = [string]$scenario.blocked_reason
      }
    } catch {
    }
  }

  $loopCount = if ($null -ne $payload.loop_count) {
    [int]$payload.loop_count
  } else {
    0
  }
  if (($missing.Count -gt 0 -or $scenarioReason) -and $loopCount -eq 0 -and
      -not $state.completion_followup_sent) {
    $state.completion_followup_sent = $true
    $state.last_response = ''
    Write-GodObjectState -Path $statePath -State $state
    $parts = @()
    if ($missing.Count -gt 0) {
      $parts += "Completion report is missing: $($missing -join '; ')."
    }
    if ($scenarioReason) {
      $parts += $scenarioReason
    }
    $parts += 'Provide one concise evidence-based follow-up; do not claim unexecuted tests passed.'
    Write-Output (@{ followup_message = ($parts -join ' ') } |
      ConvertTo-Json -Compress)
    exit 0
  }

  $state.last_response = ''
  Write-GodObjectState -Path $statePath -State $state
} catch {
  # Completion verification is advisory and fails open.
}

Write-Output '{}'
exit 0
