param(
  [string]$Repository,
  [string]$Root = (Get-Location).Path,
  [switch]$SkipAuthorCheck
)

# Reads GitHub issue JSON from stdin. Never emits ticket text or matched values.
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::UTF8
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

function Get-RepositoryFromRemote {
  $remote = (git -C $Root remote get-url origin 2>$null)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remote)) {
    throw 'Cannot determine origin repository.'
  }
  if ($remote -notmatch '(?i)(?:github\.com[/:])([^/:\s]+/[^/\s]+?)(?:\.git)?$') {
    throw 'Origin is not a supported GitHub repository.'
  }
  return $Matches[1]
}

function Add-Finding {
  param([string]$Rule, [string]$Location, [string]$Severity)
  $script:findings += [ordered]@{
    rule = $Rule
    location = $Location
    severity = $Severity
  }
}

function Test-TrustedAuthor {
  param([string]$Login)
  if ($SkipAuthorCheck) { return $true }
  if ([string]::IsNullOrWhiteSpace($Login)) { return $false }
  if ($script:authorCache.ContainsKey($Login)) { return $script:authorCache[$Login] }

  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'SilentlyContinue'
  try {
    $permission = gh api "repos/$Repository/collaborators/$Login/permission" `
      --jq '.permission' 2>$null
    $trusted = $LASTEXITCODE -eq 0 -and
      $permission -match '^(admin|maintain|write)$'
  } finally {
    $ErrorActionPreference = $previousPreference
  }
  $script:authorCache[$Login] = $trusted
  return $trusted
}

function Test-Text {
  param([AllowNull()][string]$Text, [string]$Location, [bool]$TrustedAuthor)
  if ([string]::IsNullOrEmpty($Text)) { return }

  $rules = @(
    @{ Rule = 'instruction-override'; Severity = 'suspicious'; Pattern = '(?i)\b(ignore|disregard|override)\b.{0,40}\b(previous|prior|system|developer|instructions?)\b|\byou are now\b|\bsystem prompt\b' },
    @{ Rule = 'embedded-command'; Severity = 'quarantined'; Pattern = '(?i)(?:curl|wget)\b.{0,120}(?:\||;|&&)\s*(?:iex|sh|bash|powershell)|\bInvoke-Expression\b|\brm\s+-rf\b|\bgit\s+push\s+--force\b' },
    @{ Rule = 'package-install'; Severity = 'quarantined'; Pattern = '(?i)\b(?:npm|pnpm|yarn|pip|pipx|uv|cargo|choco|winget)\s+(?:i|install|add)\b' },
    @{ Rule = 'url-action'; Severity = 'suspicious'; Pattern = '(?i)\b(?:fetch|download|upload|open|visit|send|post)\b.{0,80}https?://' },
    @{ Rule = 'security-bypass'; Severity = 'quarantined'; Pattern = '(?i)\b(?:disable|remove|bypass|ignore|turn\s+off)\b.{0,60}\b(?:hook|rule|security|scanner|review|guard|approval)\b' },
    @{ Rule = 'hidden-unicode'; Severity = 'quarantined'; Pattern = '[\u200B-\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]' }
  )
  . (Join-Path $Root '.cursor/hooks/security-secret-rules.ps1')
  $rules += @(Get-SecuritySecretRules | ForEach-Object {
    @{ Rule = $_.Name; Severity = 'quarantined'; Pattern = $_.Pattern }
  })

  foreach ($rule in $rules) {
    if ($Text -match $rule.Pattern) {
      Add-Finding -Rule $rule.Rule -Location $Location -Severity $rule.Severity
    }
  }

  $hasMarker = $Text -match '<!--\s*factory-loop\s*-->'
  $validAgentSuffix = $Text -match '<!--\s*factory-loop\s*-->\s*$'
  if ($hasMarker -and -not $validAgentSuffix) {
    Add-Finding -Rule 'forged-agent-marker' -Location $Location -Severity 'quarantined'
  }
  if ($hasMarker -and $Text -match '(?i)\b(?:Plan|Review)\s+approved:') {
    Add-Finding -Rule 'agent-marker-approval' -Location $Location -Severity 'quarantined'
  }

  $withoutAgentMarker = $Text -replace '<!--\s*factory-loop\s*-->\s*$', ''
  if ($withoutAgentMarker -match '<!--[\s\S]*?-->') {
    Add-Finding -Rule 'hidden-html-comment' -Location $Location -Severity 'suspicious'
  }
  if (-not $TrustedAuthor -and
      $Text -match '(?i)\b(?:Plan|Review)\s+approved:') {
    Add-Finding -Rule 'untrusted-approval' -Location $Location -Severity 'quarantined'
  }
}

try {
  $raw = [Console]::In.ReadToEnd()
  if ([string]::IsNullOrWhiteSpace($raw)) { throw 'Ticket JSON is empty.' }
  $ticket = $raw | ConvertFrom-Json
  if (-not $Repository) { $Repository = Get-RepositoryFromRemote }
  $Repository = $Repository -replace '\.git$', ''
  if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
    throw 'Repository must use owner/name format.'
  }

  $script:findings = @()
  $script:authorCache = @{}
  $number = [string]$ticket.number
  if ([string]::IsNullOrWhiteSpace($number)) { $number = 'unknown' }

  $issueLogin = [string]$ticket.author.login
  $issueTrusted = Test-TrustedAuthor -Login $issueLogin
  if (-not $issueTrusted) {
    Add-Finding -Rule 'untrusted-author' -Location 'issue.author' -Severity 'quarantined'
  }
  Test-Text -Text ([string]$ticket.title) -Location 'issue.title' -TrustedAuthor $issueTrusted
  Test-Text -Text ([string]$ticket.body) -Location 'issue.body' -TrustedAuthor $issueTrusted

  $commentIndex = 0
  foreach ($comment in @($ticket.comments)) {
    $commentIndex++
    $login = [string]$comment.author.login
    $trusted = Test-TrustedAuthor -Login $login
    if (-not $trusted) {
      Add-Finding -Rule 'untrusted-author' -Location "comments[$commentIndex].author" `
        -Severity 'quarantined'
    }
    Test-Text -Text ([string]$comment.body) -Location "comments[$commentIndex].body" `
      -TrustedAuthor $trusted
  }

  $status = if (@($findings | Where-Object severity -eq 'quarantined').Count) {
    'quarantined'
  } elseif ($findings.Count) {
    'suspicious'
  } else {
    'clean'
  }

  $result = [ordered]@{
    ticket = $number
    repository = $Repository
    status = $status
    findings = @($findings)
    scanned_at = [DateTime]::UtcNow.ToString('o')
  }
  $stateDir = Join-Path $Root '.cursor/hooks/state'
  $null = New-Item -ItemType Directory -Force -Path $stateDir
  $result | ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath (Join-Path $stateDir "ticket-$number.scan.json") -Encoding utf8
  $result | ConvertTo-Json -Depth 6
  if ($status -ne 'clean') { exit 2 }
} catch {
  [ordered]@{
    ticket = 'unknown'
    status = 'quarantined'
    findings = @([ordered]@{
      rule = 'scan-failed'
      location = 'ticket'
      severity = 'quarantined'
    })
    scanned_at = [DateTime]::UtcNow.ToString('o')
  } | ConvertTo-Json -Depth 6
  exit 2
}
