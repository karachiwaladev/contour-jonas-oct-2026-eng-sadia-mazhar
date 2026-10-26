# Cursor postToolUse(Write): inspect only the changed repository text file.
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::UTF8
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

function Write-EmptyResult {
  Write-Output '{}'
  exit 0
}

try {
  $raw = [Console]::In.ReadToEnd()
  if ([string]::IsNullOrWhiteSpace($raw)) { Write-EmptyResult }
  $payload = $raw | ConvertFrom-Json
  $root = if ($payload.workspace_roots -and $payload.workspace_roots.Count) {
    [string]$payload.workspace_roots[0]
  } else {
    (Get-Location).Path
  }

  $toolInput = $payload.tool_input
  if ($toolInput -is [string]) {
    try { $toolInput = $toolInput | ConvertFrom-Json } catch { $toolInput = $null }
  }
  $candidate = if ($toolInput) {
    @($toolInput.path, $toolInput.file_path, $toolInput.target_file) |
      Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
      Select-Object -First 1
  }
  if (-not $candidate) { Write-EmptyResult }

  $rootFull = [IO.Path]::GetFullPath($root).TrimEnd('\', '/')
  $pathFull = [IO.Path]::GetFullPath([string]$candidate)
  $rootPrefix = $rootFull + [IO.Path]::DirectorySeparatorChar
  if (-not $pathFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Path -LiteralPath $pathFull -PathType Leaf)) {
    Write-EmptyResult
  }

  $relative = $pathFull.Substring($rootFull.Length).TrimStart('\', '/')
  $normalized = ($relative -replace '\\', '/').ToLowerInvariant()
  if ($normalized -match '(^|/)(\.git|node_modules|vendor|dist|build|coverage|out|target|\.next|\.cache|\.tmp)(/|$)' -or
      $normalized -match '^\.cursor/(prompt-log|hooks/state)/' -or
      $normalized -match '^docs/screenshots/' -or
      $normalized -match '(\.min\.(js|css)|\.map|\.lock|\.png|\.jpe?g|\.gif|\.webp|\.pdf|\.zip)$') {
    Write-EmptyResult
  }

  $file = Get-Item -LiteralPath $pathFull
  if ($file.Length -gt 1MB) { Write-EmptyResult }
  $content = @(Get-Content -LiteralPath $pathFull -Encoding utf8)

  $rules = @(
    @{ Name = 'private-key-header'; Pattern = '-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' },
    @{ Name = 'github-token'; Pattern = '\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b' },
    @{ Name = 'aws-access-key'; Pattern = '\b(?:AKIA|ASIA)[A-Z0-9]{16}\b' },
    @{ Name = 'assigned-secret'; Pattern = '(?i)\b(?:api[_-]?key|client[_-]?secret|access[_-]?token|password)\b\s*[:=]\s*["''][A-Za-z0-9+/_.=-]{16,}["'']' }
  )

  $safeConversation = if ([string]::IsNullOrWhiteSpace([string]$payload.conversation_id)) {
    'unknown'
  } else {
    ([string]$payload.conversation_id -replace '[^\w\-]', '_')
  }
  $stateDir = Join-Path $rootFull '.cursor/hooks/state'
  $null = New-Item -ItemType Directory -Force -Path $stateDir
  $statePath = Join-Path $stateDir "$safeConversation.security.json"
  $state = [ordered]@{
    generation_id = [string]$payload.generation_id
    reported = @()
    audit_files = @()
    followup_sent = $false
  }
  if (Test-Path -LiteralPath $statePath) {
    try {
      $saved = Get-Content -LiteralPath $statePath -Raw -Encoding utf8 | ConvertFrom-Json
      if ([string]$saved.generation_id -eq [string]$payload.generation_id) {
        $state.reported = @($saved.reported)
        $state.audit_files = @($saved.audit_files)
        $state.followup_sent = [bool]$saved.followup_sent
      }
    } catch {
    }
  }

  if ($normalized -match '^docs/security/audits/[^/]+\.md$' -and
      $relative -notin @($state.audit_files)) {
    $state.audit_files = @($state.audit_files + $relative)
  }

  $warnings = @()
  for ($index = 0; $index -lt $content.Count; $index++) {
    foreach ($rule in $rules) {
      if ([string]$content[$index] -match $rule.Pattern) {
        $lineNumber = $index + 1
        $key = "$relative|$($rule.Name)|$lineNumber"
        if ($key -notin @($state.reported)) {
          $state.reported = @($state.reported + $key)
          $warnings += "$($rule.Name) at $relative`:$lineNumber"
        }
      }
    }
  }
  $state | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath $statePath -Encoding utf8

  if ($warnings.Count) {
    $message = 'Potential secret material detected (values withheld): ' +
      ($warnings -join '; ') +
      '. Verify it is synthetic; remove/rotate real credentials before delivery.'
    Write-Output (@{ additional_context = $message } | ConvertTo-Json -Compress)
    exit 0
  }
} catch {
  # Advisory post-write inspection fails open and never prints file content.
}

Write-Output '{}'
exit 0
