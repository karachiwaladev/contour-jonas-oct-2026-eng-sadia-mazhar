# Cursor beforeSubmitPrompt: queue user prompts for JSONL flush on stop.
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::UTF8
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) {
  Write-Output '{"continue":true}'
  exit 0
}

$payload = $raw | ConvertFrom-Json
$conversationId = $payload.conversation_id
if ([string]::IsNullOrWhiteSpace($conversationId)) {
  Write-Output '{"continue":true}'
  exit 0
}

$root = if ($payload.workspace_roots -and $payload.workspace_roots.Count -gt 0) {
  $payload.workspace_roots[0]
} else {
  (Get-Location).Path
}

$stateDir = Join-Path $root '.cursor/hooks/state'
$null = New-Item -ItemType Directory -Force -Path $stateDir

$safeId = ($conversationId -replace '[^\w\-]', '_')
$pendingPath = Join-Path $stateDir "$safeId.pending.jsonl"

$record = [ordered]@{
  event            = 'user_prompt'
  recorded_at      = (Get-Date).ToUniversalTime().ToString('o')
  conversation_id  = $conversationId
  generation_id    = $payload.generation_id
  model            = $payload.model
  prompt           = $payload.prompt
  attachments      = @($payload.attachments)
}

$line = ($record | ConvertTo-Json -Compress -Depth 6)
Add-Content -Path $pendingPath -Value $line -Encoding utf8

. (Join-Path $PSScriptRoot 'write-prompt-log.ps1')
Write-PromptLog -Record $record

Write-Output '{"continue":true}'
exit 0
