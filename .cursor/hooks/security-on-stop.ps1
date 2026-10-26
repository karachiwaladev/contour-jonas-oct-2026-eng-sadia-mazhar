# Cursor stop: request one evidence correction for an edited security audit.
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
  $loopCount = if ($null -ne $payload.loop_count) { [int]$payload.loop_count } else { 0 }
  if ($loopCount -gt 0) {
    Write-Output '{}'
    exit 0
  }

  $root = if ($payload.workspace_roots -and $payload.workspace_roots.Count) {
    [string]$payload.workspace_roots[0]
  } else {
    (Get-Location).Path
  }
  $safeConversation = if ([string]::IsNullOrWhiteSpace([string]$payload.conversation_id)) {
    'unknown'
  } else {
    ([string]$payload.conversation_id -replace '[^\w\-]', '_')
  }
  $statePath = Join-Path $root ".cursor/hooks/state/$safeConversation.security.json"
  if (-not (Test-Path -LiteralPath $statePath)) {
    Write-Output '{}'
    exit 0
  }
  $state = Get-Content -LiteralPath $statePath -Raw -Encoding utf8 | ConvertFrom-Json
  if ([string]$state.generation_id -ne [string]$payload.generation_id -or
      @($state.audit_files).Count -eq 0 -or [bool]$state.followup_sent) {
    Write-Output '{}'
    exit 0
  }

  $validator = Join-Path $root '.cursor/tools/validate-security-audit.ps1'
  if (-not (Test-Path -LiteralPath $validator)) {
    Write-Output '{}'
    exit 0
  }
  $arguments = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $validator,
    '-Root', $root, '-Json', '-Path'
  ) + @($state.audit_files)
  $validationRaw = & powershell @arguments 2>$null
  try {
    $validation = ($validationRaw -join "`n") | ConvertFrom-Json
  } catch {
    $validation = $null
  }

  if (-not $validation -or -not [bool]$validation.valid) {
    $state.followup_sent = $true
    $state | ConvertTo-Json -Depth 5 |
      Set-Content -LiteralPath $statePath -Encoding utf8
    $detail = if ($validation -and $validation.errors) {
      "$(@($validation.errors).Count) documentation/evidence issue(s)"
    } else {
      'validator execution was not confirmed'
    }
    $message = "The edited security audit has $detail. Run .cursor/tools/validate-security-audit.ps1 for the listed fields, record actual Run/Not run/Failed/Blocked outcomes and cost, and do not claim unexecuted checks succeeded."
    Write-Output (@{ followup_message = $message } | ConvertTo-Json -Compress)
    exit 0
  }
} catch {
  # Completion evidence hook is advisory and fails open.
}

Write-Output '{}'
exit 0
