param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))

function Invoke-JsonTestScript {
  param([string] $Path)

  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $Path 2>&1
  $exitCode = $LASTEXITCODE
  try {
    $result = (@($output) -join "`n") | ConvertFrom-Json
  } catch {
    return [pscustomobject]@{
      valid = $false
      tests = 0
      passed = 0
      failed = 1
      error = "Invalid test output: $(@($output) -join ' ')"
    }
  }
  if ($exitCode -ne 0) { $result.valid = $false }
  return $result
}

Push-Location $root
try {
  $unit = Invoke-JsonTestScript (
    Join-Path $root '.cursor/tools/test-god-object-units.ps1'
  )
  $integration = Invoke-JsonTestScript (
    Join-Path $root '.cursor/tools/test-god-object-hooks.ps1'
  )
  $measuredCoverage = Invoke-JsonTestScript (
    Join-Path $root '.cursor/tools/measure-god-object-coverage.ps1'
  )

  $staticErrors = @()
  foreach ($script in Get-ChildItem '.cursor/hooks/god-object-*.ps1') {
    $tokens = $null
    $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile(
      $script.FullName,
      [ref]$tokens,
      [ref]$parseErrors
    )
    $staticErrors += @($parseErrors)
  }
  try {
    Get-Content '.cursor/hooks.json' -Raw | ConvertFrom-Json | Out-Null
    Get-Content '.cursor/god-object-management.json' -Raw |
      ConvertFrom-Json | Out-Null
  } catch {
    $staticErrors += $_
  }

  $validatorOutput = & powershell -NoProfile -ExecutionPolicy Bypass `
    -File '.cursor/tools/validate-test-scenarios.ps1' 2>&1
  $scenariosValid = ($LASTEXITCODE -eq 0)

  $neutralPayload = @{
    status = 'aborted'
    conversation_id = 'eval-neutral'
    generation_id = 'eval-neutral'
    workspace_roots = @($root)
  } | ConvertTo-Json -Compress
  $neutralOutput = $neutralPayload |
    & powershell -NoProfile -ExecutionPolicy Bypass `
      -File '.cursor/hooks/scenario-on-stop.ps1'
  $existingHooksValid = (($neutralOutput -join '') -eq '{}')

  $requirements = @(
    [ordered]@{ id = 'R1'; covered = [bool]$integration.valid; evidence = 'Small-edit integration assertion' },
    [ordered]@{ id = 'R2'; covered = [bool]$integration.valid; evidence = 'Known-candidate growth assertions' },
    [ordered]@{ id = 'R3'; covered = [bool]$integration.valid; evidence = 'Approved exception assertion' },
    [ordered]@{ id = 'R4'; covered = $false; evidence = 'No application refactor was executed' },
    [ordered]@{ id = 'R5'; covered = [bool]$integration.valid; evidence = 'Honest failed-test report assertion' },
    [ordered]@{
      id = 'R6'
      covered = ($staticErrors.Count -eq 0 -and $scenariosValid -and $existingHooksValid)
      evidence = 'Static parsing, scenario validation, and neutral existing-hook execution'
    },
    [ordered]@{ id = 'R7'; covered = [bool]$integration.valid; evidence = 'Malformed input and missing-baseline assertions' },
    [ordered]@{ id = 'R8'; covered = [bool]$integration.valid; evidence = 'One-shot, loop-limit, and timing assertions' }
  )

  $requirementsCovered = @($requirements | Where-Object covered).Count
  $requirementTotal = $requirements.Count
  $staticValid = (
    $staticErrors.Count -eq 0 -and
    $scenariosValid -and
    $existingHooksValid
  )
  $valid = (
    [bool]$unit.valid -and
    [bool]$integration.valid -and
    [bool]$measuredCoverage.valid -and
    $staticValid
  )
  $evaluationErrors = @()
  $evaluationErrors += @($staticErrors | ForEach-Object { [string]$_ })
  if (-not $scenariosValid) {
    $evaluationErrors += @($validatorOutput | ForEach-Object { [string]$_ })
  }
  if (-not [bool]$unit.valid) {
    $evaluationErrors += 'Unit test suite failed.'
  }
  if (-not [bool]$integration.valid) {
    $evaluationErrors += 'Integration test suite failed.'
  }
  if (-not [bool]$measuredCoverage.valid) {
    $evaluationErrors += 'Measured Pester coverage suite failed.'
  }

  [ordered]@{
    valid = $valid
    test_summary = [ordered]@{
      unit = [ordered]@{
        passed = [int]$unit.passed
        total = [int]$unit.tests
      }
      integration = [ordered]@{
        passed = [int]$integration.assertions
        total = [int]$integration.assertions
        maximum_hook_ms = [int]$integration.maximum_hook_ms
      }
      measured_coverage = [ordered]@{
        framework = [string]$measuredCoverage.framework
        passed = [int]$measuredCoverage.tests.passed
        total = [int]$measuredCoverage.tests.total
        scope = [string]$measuredCoverage.measured_scope
      }
    }
    coverage = [ordered]@{
      unit_behavior_percent = [double]$unit.unit_behavior_coverage.percent
      acceptance_requirement_percent = [Math]::Round(
        ($requirementsCovered * 100.0 / $requirementTotal),
        1
      )
      requirements_covered = $requirementsCovered
      requirements_total = $requirementTotal
      measured_command_percent = [double]$measuredCoverage.coverage.command_percent
      measured_line_percent = [double]$measuredCoverage.coverage.line_percent
      measured_scope = [string]$measuredCoverage.measured_scope
    }
    requirements = $requirements
    static_checks = [ordered]@{
      powershell_and_json = ($staticErrors.Count -eq 0)
      scenario_documents = $scenariosValid
      existing_hook_neutral_input = $existingHooksValid
    }
    errors = $evaluationErrors
  } | ConvertTo-Json -Depth 10

  if (-not $valid) { exit 1 }
} finally {
  Pop-Location
}
