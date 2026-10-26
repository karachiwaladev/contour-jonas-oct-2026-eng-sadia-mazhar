param()

$ErrorActionPreference = 'Stop'
$script:Passed = 0
$script:Durations = @()
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixture = Join-Path ([IO.Path]::GetTempPath()) (
  'god-object-hook-tests-' + [guid]::NewGuid().ToString('N')
)

function Assert-True {
  param([bool] $Condition, [string] $Message)
  if (-not $Condition) { throw "Assertion failed: $Message" }
  $script:Passed++
}

function Invoke-TestHook {
  param(
    [string] $Name,
    [object] $Payload,
    [switch] $Raw,
    [string] $RawInput = ''
  )

  $scriptPath = Join-Path $fixture ".cursor/hooks/$Name"
  $inputText = if ($Raw) {
    $RawInput
  } else {
    $Payload | ConvertTo-Json -Depth 12 -Compress
  }
  $watch = [Diagnostics.Stopwatch]::StartNew()
  Push-Location $fixture
  try {
    $output = $inputText | & powershell -NoProfile -ExecutionPolicy Bypass `
      -File $scriptPath
    $exitCode = $LASTEXITCODE
  } finally {
    Pop-Location
    $watch.Stop()
  }
  $script:Durations += $watch.ElapsedMilliseconds
  if ($exitCode -ne 0) { throw "$Name exited with $exitCode" }
  $joined = @($output) -join "`n"
  if ([string]::IsNullOrWhiteSpace($joined)) { return $null }
  return $joined | ConvertFrom-Json
}

function New-Payload {
  param([string] $Conversation, [string] $Generation = 'generation-1')
  return [ordered]@{
    conversation_id = $Conversation
    generation_id = $Generation
    workspace_roots = @($fixture)
  }
}

try {
  $hooksDir = Join-Path $fixture '.cursor/hooks'
  $stateDir = Join-Path $hooksDir 'state'
  $null = New-Item -ItemType Directory -Force -Path $stateDir
  $null = New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'src')
  Copy-Item (Join-Path $repoRoot '.cursor/hooks/god-object-*.ps1') $hooksDir

  @{
    version = 1
    growth = @{
      substantialAddedLines = 5
      minimumPercentageAddedLines = 3
      percentageOfBaseline = 25
      minimumBaselineLines = 10
    }
    activeAnalysis = 'analysis.md'
    candidateFiles = @('src/large.js')
    excludedPaths = @('.git/', '.cursor/hooks/state/')
  } | ConvertTo-Json -Depth 8 |
    Set-Content (Join-Path $fixture '.cursor/god-object-management.json') -Encoding utf8

  1..20 | ForEach-Object { "// large $_" } |
    Set-Content (Join-Path $fixture 'src/large.js') -Encoding utf8
  1..20 | ForEach-Object { "// small $_" } |
    Set-Content (Join-Path $fixture 'src/small.js') -Encoding utf8
  & git -C $fixture init --quiet
  & git -C $fixture config user.email 'fixture@example.invalid'
  & git -C $fixture config user.name 'Hook Fixture'
  & git -C $fixture add src
  & git -C $fixture commit --quiet -m 'fixture baseline'

  # Small growth: no warning.
  Add-Content (Join-Path $fixture 'src/small.js') '// one'
  $small = New-Payload -Conversation 'small'
  $small.file_path = Join-Path $fixture 'src/small.js'
  $small.edits = @(@{ old_string = ''; new_string = '// one' })
  $null = Invoke-TestHook 'god-object-after-file-edit.ps1' $small
  $smallPost = New-Payload -Conversation 'small'
  $smallPost.tool_input = @{ path = 'src/small.js' }
  $smallResult = Invoke-TestHook 'god-object-post-tool-use.ps1' $smallPost
  Assert-True (-not $smallResult.additional_context) `
    'a one-line change must not trigger growth feedback'

  # Substantial candidate growth: warning once, without blocking.
  1..6 | ForEach-Object { Add-Content (Join-Path $fixture 'src/large.js') "// add $_" }
  $large = New-Payload -Conversation 'large'
  $large.file_path = Join-Path $fixture 'src/large.js'
  $large.edits = @(@{ old_string = ''; new_string = ((1..6 | ForEach-Object { "// add $_" }) -join "`n") })
  $null = Invoke-TestHook 'god-object-after-file-edit.ps1' $large
  $largePost = New-Payload -Conversation 'large'
  $largePost.tool_input = @{ path = 'src/large.js' }
  $largeResult = Invoke-TestHook 'god-object-post-tool-use.ps1' $largePost
  Assert-True ($largeResult.additional_context -match 'grew by 6 lines') `
    'substantial growth must report the measured delta'
  Assert-True ($largeResult.additional_context -match 'active God Object analysis') `
    'known candidates must be identified'
  $largeAgain = Invoke-TestHook 'god-object-post-tool-use.ps1' $largePost
  Assert-True (-not $largeAgain.additional_context) `
    'growth feedback must be one-shot'

  # Scope exceptions remain possible; unrelated edits warn once.
  @{
    version = 1
    mode = 'implementation'
    ticket = 'fixture ticket'
    approved_paths = @('src/large.js')
    candidate_paths = @('src/large.js')
    exceptions = @(@{ path = 'src/justified.js'; reason = 'approved adapter' })
    architecture_decisions = @('growth logic -> fixture owner')
    intentionally_incomplete = $false
  } | ConvertTo-Json -Depth 8 |
    Set-Content (Join-Path $stateDir 'god-object-active-scope.json') -Encoding utf8

  $justified = New-Payload -Conversation 'scope'
  $justified.tool_input = @{ path = 'src/justified.js' }
  $justifiedResult = Invoke-TestHook 'god-object-post-tool-use.ps1' $justified
  Assert-True (-not $justifiedResult.additional_context) `
    'documented exceptions must remain allowed without warning'

  $outside = New-Payload -Conversation 'scope'
  $outside.tool_input = @{ path = 'src/outside.js' }
  $outsideResult = Invoke-TestHook 'god-object-post-tool-use.ps1' $outside
  Assert-True ($outsideResult.additional_context -match 'outside the approved paths') `
    'out-of-scope writes must produce advisory feedback'
  $outsideAgain = Invoke-TestHook 'god-object-post-tool-use.ps1' $outside
  Assert-True (-not $outsideAgain.additional_context) `
    'scope feedback must be one-shot'

  $scopeReport = New-Payload -Conversation 'scope' -Generation 'generation-2'
  $scopeReport.text = @'
## Changed files
- src/large.js
## Tests
- Fixture command: Passed.
## Architecture
- Growth logic remains with the fixture owner.
## Unresolved
- None.
'@
  $null = Invoke-TestHook 'god-object-after-agent-response.ps1' $scopeReport
  $scopeStop = New-Payload -Conversation 'scope' -Generation 'generation-2'
  $scopeStop.status = 'completed'
  $scopeStop.loop_count = 0
  $scopeStopResult = Invoke-TestHook 'god-object-on-stop.ps1' $scopeStop
  Assert-True ($scopeStopResult.followup_message -match 'src/outside.js') `
    'scope warnings must survive generation changes until disposition'

  # Missing Git baseline uses edit delta safely.
  1..7 | ForEach-Object { "// new $_" } |
    Set-Content (Join-Path $fixture 'src/new.js') -Encoding utf8
  $untracked = New-Payload -Conversation 'untracked'
  $untracked.file_path = Join-Path $fixture 'src/new.js'
  $untracked.edits = @(@{
      old_string = ''
      new_string = ((1..7 | ForEach-Object { "// new $_" }) -join "`n")
    })
  $null = Invoke-TestHook 'god-object-after-file-edit.ps1' $untracked
  $untrackedPost = New-Payload -Conversation 'untracked'
  $untrackedPost.tool_input = @{ path = 'src/new.js' }
  $untrackedResult = Invoke-TestHook 'god-object-post-tool-use.ps1' $untrackedPost
  Assert-True ($untrackedResult.additional_context -match 'grew by 7 lines') `
    'untracked files must use the edit delta fallback'

  # Completion report checks and bounded follow-up.
  $incomplete = New-Payload -Conversation 'completion'
  $incomplete.text = 'Implemented the ticket.'
  $null = Invoke-TestHook 'god-object-after-agent-response.ps1' $incomplete
  $stop = New-Payload -Conversation 'completion'
  $stop.status = 'completed'
  $stop.loop_count = 0
  $stopResult = Invoke-TestHook 'god-object-on-stop.ps1' $stop
  Assert-True ($stopResult.followup_message -match 'tests and actual results') `
    'completion must request missing test evidence'
  $stop.loop_count = 1
  $stopAgain = Invoke-TestHook 'god-object-on-stop.ps1' $stop
  Assert-True (-not $stopAgain.followup_message) `
    'completion follow-up must not loop'

  $followupResponse = New-Payload -Conversation 'completion' -Generation 'generation-2'
  $followupResponse.text = 'Still incomplete.'
  $null = Invoke-TestHook 'god-object-after-agent-response.ps1' $followupResponse
  $followupStop = New-Payload -Conversation 'completion' -Generation 'generation-2'
  $followupStop.status = 'completed'
  $followupStop.loop_count = 0
  $followupStopResult = Invoke-TestHook 'god-object-on-stop.ps1' $followupStop
  Assert-True (-not $followupStopResult.followup_message) `
    'completion one-shot guard must survive generation changes'

  $complete = New-Payload -Conversation 'complete'
  $complete.text = @'
## Changed files
- src/large.js
## Tests
- Fixture command: Failed (expected negative fixture).
## Architecture
- Growth logic remains with the fixture owner.
## Unresolved
- None.
'@
  $null = Invoke-TestHook 'god-object-after-agent-response.ps1' $complete
  $completeStop = New-Payload -Conversation 'complete'
  $completeStop.status = 'completed'
  $completeStop.loop_count = 0
  $completeResult = Invoke-TestHook 'god-object-on-stop.ps1' $completeStop
  Assert-True (-not $completeResult.followup_message) `
    'honestly reported failing tests satisfy report completeness'

  # Investigation and intentionally incomplete modes are exempt.
  $scopePath = Join-Path $stateDir 'god-object-active-scope.json'
  $scope = Get-Content $scopePath -Raw | ConvertFrom-Json
  $scope.mode = 'investigation'
  $scope | ConvertTo-Json -Depth 8 | Set-Content $scopePath -Encoding utf8
  $investigation = New-Payload -Conversation 'investigation'
  $investigation.status = 'completed'
  $investigation.loop_count = 0
  $investigationResult = Invoke-TestHook 'god-object-on-stop.ps1' $investigation
  Assert-True (-not $investigationResult.followup_message) `
    'investigation-only tasks must skip completion enforcement'

  # Empty and malformed input fail open.
  $empty = Invoke-TestHook 'god-object-after-file-edit.ps1' $null -Raw -RawInput ''
  Assert-True ($null -ne $empty) 'empty input must return neutral JSON'
  $malformed = Invoke-TestHook 'god-object-on-stop.ps1' $null -Raw -RawInput '{bad'
  Assert-True ($null -ne $malformed) 'malformed input must return neutral JSON'

  $maximum = ($script:Durations | Measure-Object -Maximum).Maximum
  Assert-True ($maximum -lt 5000) 'each fixture hook invocation must finish under five seconds'

  [ordered]@{
    valid = $true
    assertions = $script:Passed
    maximum_hook_ms = $maximum
    note = 'Fixture tests use a disposable local Git repository.'
  } | ConvertTo-Json -Compress
} finally {
  if (Test-Path -LiteralPath $fixture) {
    Remove-Item -LiteralPath $fixture -Recurse -Force
  }
}
