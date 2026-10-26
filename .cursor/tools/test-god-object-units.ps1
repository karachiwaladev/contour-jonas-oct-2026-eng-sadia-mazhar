param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $repoRoot '.cursor/hooks/god-object-hook-common.ps1')

$results = [Collections.Generic.List[object]]::new()

function Add-UnitResult {
  param(
    [string] $Id,
    [string] $Behavior,
    [scriptblock] $Test
  )

  try {
    $passed = [bool](& $Test)
    $results.Add([ordered]@{
        id = $Id
        behavior = $Behavior
        passed = $passed
        error = if ($passed) { $null } else { 'Assertion returned false.' }
      })
  } catch {
    $results.Add([ordered]@{
        id = $Id
        behavior = $Behavior
        passed = $false
        error = $_.Exception.Message
      })
  }
}

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

Add-UnitResult 'UNIT-001' 'Conversation IDs are filesystem-safe' {
  (Get-GodObjectSafeId 'abc:/\ 123') -eq 'abc____123'
}

Add-UnitResult 'UNIT-002' 'Repository paths normalize to forward slashes' {
  $path = Join-Path $repoRoot 'src/example.js'
  (Get-GodObjectRelativePath -Path $path -Root $repoRoot) -eq 'src/example.js'
}

Add-UnitResult 'UNIT-003' 'Paths outside the repository are rejected' {
  $outside = Join-Path ([IO.Path]::GetPathRoot($repoRoot)) 'outside/example.js'
  $null -eq (Get-GodObjectRelativePath -Path $outside -Root $repoRoot)
}

Add-UnitResult 'UNIT-004' 'Exact and directory-prefix matching differ correctly' {
  (Test-GodObjectPathPrefix 'src/file.js' 'src/file.js') -and
  (Test-GodObjectPathPrefix 'src/domain/file.js' 'src/domain/') -and
  -not (Test-GodObjectPathPrefix 'src/file.js.extra' 'src/file.js')
}

Add-UnitResult 'UNIT-005' 'Configured generated paths are excluded' {
  (Test-GodObjectExcluded 'dist/bundle.js' $config) -and
  -not (Test-GodObjectExcluded 'src/bundle.js' $config)
}

Add-UnitResult 'UNIT-006' 'Approved files and directories remain in scope' {
  (Test-GodObjectApproved 'src/approved.js' $scope) -and
  (Test-GodObjectApproved 'src/domain/model.js' $scope)
}

Add-UnitResult 'UNIT-007' 'Documented exceptions remain in scope' {
  (Test-GodObjectApproved 'src/adapter.js' $scope) -and
  -not (Test-GodObjectApproved 'src/unrelated.js' $scope)
}

Add-UnitResult 'UNIT-008' 'Candidates merge config and active analysis paths' {
  (Test-GodObjectCandidate 'src/candidate.js' $config $scope) -and
  (Test-GodObjectCandidate 'src/scoped-candidate.js' $config $scope) -and
  -not (Test-GodObjectCandidate 'src/other.js' $config $scope)
}

Add-UnitResult 'UNIT-009' 'Write tool paths use supported input properties' {
  $payload = [pscustomobject]@{
    tool_input = [pscustomobject]@{ target_file = 'src/file.js' }
  }
  (Get-GodObjectToolPath $payload) -eq 'src/file.js'
}

Add-UnitResult 'UNIT-010' 'Edit deltas count additions and removals' {
  $edits = @(
    [pscustomobject]@{ old_string = "a`nb"; new_string = "a`nb`nc`nd" },
    [pscustomobject]@{ old_string = "x`ny"; new_string = 'x' }
  )
  (Get-GodObjectEditDelta $edits) -eq 1
}

Add-UnitResult 'UNIT-011' 'Absolute substantial growth triggers' {
  Test-GodObjectSubstantialGrowth 100 180 $config.growth
}

Add-UnitResult 'UNIT-012' 'Percentage growth triggers only above its floor' {
  (Test-GodObjectSubstantialGrowth 200 250 $config.growth) -and
  -not (Test-GodObjectSubstantialGrowth 200 230 $config.growth)
}

Add-UnitResult 'UNIT-013' 'Shrinks and tiny changes do not trigger' {
  -not (Test-GodObjectSubstantialGrowth 200 190 $config.growth) -and
  -not (Test-GodObjectSubstantialGrowth 20 30 $config.growth)
}

Add-UnitResult 'UNIT-014' 'Pending advisory messages are deduplicated' {
  $state = New-GodObjectState 'unit' 'generation'
  Add-GodObjectPendingMessage $state 'same warning'
  Add-GodObjectPendingMessage $state 'same warning'
  @($state.pending_messages).Count -eq 1
}

$passed = @($results | Where-Object passed).Count
$total = $results.Count
$failed = $total - $passed

[ordered]@{
  valid = ($failed -eq 0)
  tests = $total
  passed = $passed
  failed = $failed
  unit_behavior_coverage = [ordered]@{
    covered = $passed
    total = $total
    percent = if ($total -eq 0) { 0 } else {
      [Math]::Round(($passed * 100.0 / $total), 1)
    }
  }
  results = $results
} | ConvertTo-Json -Depth 8

if ($failed -gt 0) { exit 1 }
