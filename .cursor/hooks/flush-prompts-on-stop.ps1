# Cursor stop: append queued session prompts to JSONL log.
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::UTF8
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

$raw = [Console]::In.ReadToEnd()
$payload = $null
if (-not [string]::IsNullOrWhiteSpace($raw)) {
  $payload = $raw | ConvertFrom-Json
}

$conversationId = $payload.conversation_id
$root = if ($payload -and $payload.workspace_roots -and $payload.workspace_roots.Count -gt 0) {
  $payload.workspace_roots[0]
} else {
  (Get-Location).Path
}

$stateDir = Join-Path $root '.cursor/hooks/state'
$logDir = Join-Path $root '.cursor/prompt-log'
$null = New-Item -ItemType Directory -Force -Path $stateDir, $logDir

$flushed = 0

if (-not [string]::IsNullOrWhiteSpace($conversationId)) {
  $safeId = ($conversationId -replace '[^\w\-]', '_')
  $pendingPath = Join-Path $stateDir "$safeId.pending.jsonl"

  if (Test-Path $pendingPath) {
    $flushed = (Get-Content -Path $pendingPath -Encoding utf8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
    Remove-Item -Path $pendingPath -Force
  }
}

. (Join-Path $PSScriptRoot 'write-prompt-log.ps1')
$stopRecord = [ordered]@{
  event           = 'agent_stop'
  recorded_at     = (Get-Date).ToUniversalTime().ToString('o')
  conversation_id = $conversationId
  generation_id   = $payload.generation_id
  status          = $payload.status
  loop_count      = $payload.loop_count
  prompts_flushed = $flushed
}
Write-PromptLog -Record $stopRecord

Write-Output '{}'
exit 0
