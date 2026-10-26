# Cursor beforeShellExecution: require approval for costly or active security commands.
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::UTF8
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

try {
  $raw = [Console]::In.ReadToEnd()
  if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Output '{"permission":"allow"}'
    exit 0
  }
  $payload = $raw | ConvertFrom-Json
  $command = [string]$payload.command
  if ([string]::IsNullOrWhiteSpace($command) -and $payload.tool_input) {
    $inputObject = $payload.tool_input
    if ($inputObject -is [string]) {
      try { $inputObject = $inputObject | ConvertFrom-Json } catch { $inputObject = $null }
    }
    if ($inputObject) { $command = [string]$inputObject.command }
  }

  $reason = $null
  if ($command -match '(?i)(?:^|[\s;&|])(deepsec)(?:$|[\s;&|])') {
    $reason = 'DeepSec may transmit source to a model provider and incur cost.'
  } elseif ($command -match '(?i)(?:^|[\s;&|])(nmap|nikto|sqlmap|nuclei|masscan|msfconsole)(?:$|[\s;&|])') {
    $reason = 'Active security tooling requires a confirmed authorized target and safe scope.'
  } elseif ($command -match '(?i)\b(?:npm|pnpm|yarn|pip|pipx|uv|cargo|brew|choco|winget)\b.*\b(?:deepsec|nmap|nikto|sqlmap|nuclei|masscan|metasploit)\b') {
    $reason = 'Installing security tooling requires approval, purpose, source, and cost review.'
  }

  if ($reason) {
    $output = @{
      permission = 'ask'
      user_message = "$reason Review the exact command, target, data boundary, time limit, and cost cap before continuing."
      agent_message = 'Do not execute until the user explicitly approves this command and scope.'
    }
    Write-Output ($output | ConvertTo-Json -Compress)
    exit 0
  }
} catch {
  # Matcher is narrow; unexpected parsing failures fail closed.
  Write-Output (@{
      permission = 'ask'
      user_message = 'The security-command approval hook could not validate this matched command.'
      agent_message = 'Ask the user to review the command before execution.'
    } | ConvertTo-Json -Compress)
  exit 0
}

Write-Output '{"permission":"allow"}'
exit 0
