function Write-PromptLog {
  param(
    [Parameter(Mandatory = $true)]
    [object] $Record
  )

  $ErrorActionPreference = 'Stop'
  $root = if ($env:CURSOR_WORKSPACE_ROOT) { $env:CURSOR_WORKSPACE_ROOT } else { (Get-Location).Path }
  $logDir = Join-Path $root '.cursor/prompt-log'
  $null = New-Item -ItemType Directory -Force -Path $logDir
  $logPath = Join-Path $logDir 'prompts.jsonl'

  $hash = @{}
  foreach ($key in $Record.Keys) {
    $hash[$key] = $Record[$key]
  }
  if (-not $hash.ContainsKey('recorded_at') -or [string]::IsNullOrWhiteSpace($hash['recorded_at'])) {
    $hash['recorded_at'] = (Get-Date).ToUniversalTime().ToString('o')
  }

  $line = ($hash | ConvertTo-Json -Compress -Depth 8)
  Add-Content -Path $logPath -Value $line -Encoding utf8
}
