BeforeAll {
  $repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  . (Join-Path $repoRoot '.cursor/hooks/god-object-hook-common.ps1')

  $config = @'
{
  "growth": {
    "substantialAddedLines": 80,
    "minimumPercentageAddedLines": 40,
    "percentageOfBaseline": 25,
    "minimumBaselineLines": 100
  },
  "candidateFiles": ["src/candidate.js"],
  "excludedPaths": [".git/", "dist/"]
}
'@ | ConvertFrom-Json

  $scope = @'
{
  "approved_paths": ["src/approved.js", "src/domain/"],
  "candidate_paths": ["src/scoped-candidate.js"],
  "exceptions": [
    { "path": "src/adapter.js", "reason": "approved adapter" }
  ]
}
'@ | ConvertFrom-Json
}

Describe 'God Object hook common helpers' {
  It 'resolves workspace roots from hook payloads' {
    $payload = [pscustomobject]@{ workspace_roots = @($TestDrive) }
    Get-GodObjectWorkspaceRoot $payload | Should -Be ([IO.Path]::GetFullPath($TestDrive))

    Push-Location $TestDrive
    try {
      Get-GodObjectWorkspaceRoot $null |
        Should -Be ([IO.Path]::GetFullPath($TestDrive))
    } finally {
      Pop-Location
    }
  }

  It 'creates filesystem-safe conversation IDs' {
    Get-GodObjectSafeId 'abc:/\ 123' | Should -Be 'abc____123'
    Get-GodObjectSafeId '' | Should -Be 'unknown'
  }

  It 'creates deterministic state and scope paths' {
    $statePath = Get-GodObjectStatePath $TestDrive 'conversation:1'
    $statePath | Should -Be (Join-Path $TestDrive '.cursor/hooks/state/conversation_1.god-object.json')
    Test-Path (Split-Path $statePath) | Should -BeTrue
    Get-GodObjectScopePath $TestDrive |
      Should -Be (Join-Path $TestDrive '.cursor/hooks/state/god-object-active-scope.json')
  }

  It 'creates, writes, and reads state without losing maps or flags' {
    $path = Get-GodObjectStatePath $TestDrive 'state'
    $state = New-GodObjectState 'state' 'generation-1'
    $state.baselines['src/file.js'] = 10
    $state.growth_warned = @('src/file.js')
    Write-GodObjectState $path $state

    $actual = Read-GodObjectState $path 'state' 'generation-1'
    $actual.baselines['src/file.js'] | Should -Be 10
    $actual.growth_warned | Should -Contain 'src/file.js'
  }

  It 'advances generation without losing conversation-level guards' {
    $path = Get-GodObjectStatePath $TestDrive 'reset'
    $state = New-GodObjectState 'reset' 'generation-1'
    $state.scope_warned = @('src/old.js')
    $state.scope_ticket = 'ticket-1'
    $state.completion_followup_sent = $true
    $state.completion_ticket = 'ticket-1'
    $state.last_response = 'old response'
    Write-GodObjectState $path $state

    $actual = Read-GodObjectState $path 'reset' 'generation-2' -ResetForGeneration
    $actual.generation_id | Should -Be 'generation-2'
    $actual.scope_warned | Should -Contain 'src/old.js'
    $actual.scope_ticket | Should -Be 'ticket-1'
    $actual.completion_followup_sent | Should -BeTrue
    $actual.completion_ticket | Should -Be 'ticket-1'
    $actual.last_response | Should -BeNullOrEmpty
  }

  It 'recovers from missing and malformed state files' {
    $missingPath = Join-Path $TestDrive '.cursor/hooks/state/missing.json'
    $missing = Read-GodObjectState $missingPath 'missing' 'generation'
    $missing.conversation_id | Should -Be 'missing'

    $malformedPath = Join-Path $TestDrive '.cursor/hooks/state/malformed.json'
    '{bad' | Set-Content $malformedPath
    $malformed = Read-GodObjectState $malformedPath 'malformed' 'generation'
    $malformed.conversation_id | Should -Be 'malformed'
  }

  It 'loads valid configuration and safely rejects malformed configuration' {
    $cursor = Join-Path $TestDrive '.cursor'
    New-Item -ItemType Directory -Force $cursor | Out-Null
    Read-GodObjectConfig (Join-Path $TestDrive 'missing-config') |
      Should -BeNullOrEmpty
    '{"version":1}' | Set-Content (Join-Path $cursor 'god-object-management.json')
    (Read-GodObjectConfig $TestDrive).version | Should -Be 1
    '{bad' | Set-Content (Join-Path $cursor 'god-object-management.json')
    Read-GodObjectConfig $TestDrive | Should -BeNullOrEmpty
  }

  It 'loads only version-one active scope manifests' {
    $scopePath = Get-GodObjectScopePath $TestDrive
    Read-GodObjectScope (Join-Path $TestDrive 'missing-scope') |
      Should -BeNullOrEmpty
    '{"version":1,"mode":"implementation"}' | Set-Content $scopePath
    (Read-GodObjectScope $TestDrive).mode | Should -Be 'implementation'
    '{"version":2}' | Set-Content $scopePath
    Read-GodObjectScope $TestDrive | Should -BeNullOrEmpty
    '{bad' | Set-Content $scopePath
    Read-GodObjectScope $TestDrive | Should -BeNullOrEmpty
  }

  It 'normalizes repository paths and rejects outside paths' {
    $inside = Join-Path $TestDrive 'src/example.js'
    Get-GodObjectRelativePath $inside $TestDrive | Should -Be 'src/example.js'
    Get-GodObjectRelativePath 'src/relative.js' $TestDrive |
      Should -Be 'src/relative.js'
    Get-GodObjectRelativePath '' $TestDrive | Should -BeNullOrEmpty
    $outside = Join-Path (Split-Path $TestDrive -Parent) 'outside/example.js'
    Get-GodObjectRelativePath $outside $TestDrive | Should -BeNullOrEmpty
    Get-GodObjectRelativePath 'src/example.js' '"' | Should -BeNullOrEmpty
  }

  It 'distinguishes exact paths from directory prefixes' {
    Test-GodObjectPathPrefix 'src/file.js' 'src/file.js' | Should -BeTrue
    Test-GodObjectPathPrefix 'src/domain/file.js' 'src/domain/' | Should -BeTrue
    Test-GodObjectPathPrefix 'src/file.js.extra' 'src/file.js' | Should -BeFalse
    Test-GodObjectPathPrefix 'src/file.js' '' | Should -BeFalse
  }

  It 'classifies exclusions and candidates from config and active scope' {
    Test-GodObjectExcluded 'dist/bundle.js' $config | Should -BeTrue
    Test-GodObjectExcluded 'src/bundle.js' $config | Should -BeFalse
    Test-GodObjectCandidate 'src/candidate.js' $config $scope | Should -BeTrue
    Test-GodObjectCandidate 'src/scoped-candidate.js' $config $scope | Should -BeTrue
    Test-GodObjectCandidate 'src/other.js' $config $scope | Should -BeFalse
  }

  It 'allows approved paths and documented exceptions only' {
    Test-GodObjectApproved 'src/approved.js' $scope | Should -BeTrue
    Test-GodObjectApproved 'src/domain/model.js' $scope | Should -BeTrue
    Test-GodObjectApproved 'src/adapter.js' $scope | Should -BeTrue
    Test-GodObjectApproved 'src/unrelated.js' $scope | Should -BeFalse
    Test-GodObjectApproved 'src/unscoped.js' $null | Should -BeTrue
  }

  It 'extracts supported file path properties from write tool input' {
    $payload = [pscustomobject]@{
      tool_input = [pscustomobject]@{ target_file = 'src/file.js' }
    }
    Get-GodObjectToolPath $payload | Should -Be 'src/file.js'
    Get-GodObjectToolPath ([pscustomobject]@{}) | Should -BeNullOrEmpty
    Get-GodObjectToolPath ([pscustomobject]@{
        tool_input = [pscustomobject]@{ unsupported = 'src/file.js' }
      }) | Should -BeNullOrEmpty
  }

  It 'counts file lines and returns zero for missing files' {
    $path = Join-Path $TestDrive 'lines.txt'
    "one`ntwo`nthree" | Set-Content $path
    Get-GodObjectLineCount $path | Should -Be 3
    Get-GodObjectLineCount (Join-Path $TestDrive 'missing.txt') | Should -Be 0
  }

  It 'reads a committed Git baseline and handles untracked files' {
    $gitRoot = Join-Path $TestDrive 'git'
    New-Item -ItemType Directory $gitRoot | Out-Null
    & git -C $gitRoot init --quiet
    & git -C $gitRoot config user.email 'fixture@example.invalid'
    & git -C $gitRoot config user.name 'Coverage Fixture'
    & git -C $gitRoot config core.autocrlf false
    "one`ntwo" | Set-Content (Join-Path $gitRoot 'tracked.txt')
    & git -C $gitRoot add tracked.txt
    & git -C $gitRoot commit --quiet -m baseline

    Get-GodObjectGitBaseline $gitRoot 'tracked.txt' | Should -Be 2
    Get-GodObjectGitBaseline $gitRoot 'missing.txt' | Should -BeNullOrEmpty
  }

  It 'calculates net edit line deltas' {
    $edits = @(
      [pscustomobject]@{ old_string = "a`nb"; new_string = "a`nb`nc`nd" },
      [pscustomobject]@{ old_string = "x`ny"; new_string = 'x' }
    )
    Get-GodObjectEditDelta $edits | Should -Be 1

    $emptyEdits = @(
      [pscustomobject]@{ old_string = ''; new_string = 'added' },
      [pscustomobject]@{ old_string = 'removed'; new_string = '' }
    )
    Get-GodObjectEditDelta $emptyEdits | Should -Be 0
  }

  It 'applies absolute and percentage growth thresholds' {
    Test-GodObjectSubstantialGrowth 100 180 $config.growth | Should -BeTrue
    Test-GodObjectSubstantialGrowth 200 250 $config.growth | Should -BeTrue
    Test-GodObjectSubstantialGrowth 200 230 $config.growth | Should -BeFalse
    Test-GodObjectSubstantialGrowth 200 190 $config.growth | Should -BeFalse
  }

  It 'deduplicates pending advisory messages' {
    $state = New-GodObjectState 'unit' 'generation'
    Add-GodObjectPendingMessage $state 'same warning'
    Add-GodObjectPendingMessage $state 'same warning'
    @($state.pending_messages).Count | Should -Be 1
  }
}
