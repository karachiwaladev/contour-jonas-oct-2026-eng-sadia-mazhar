param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$tests = Join-Path $root '.cursor/tests/god-object-management.Tests.ps1'
$target = Join-Path $root '.cursor/hooks/god-object-hook-common.ps1'
$report = Join-Path ([IO.Path]::GetTempPath()) (
  'god-object-coverage-' + [guid]::NewGuid().ToString('N') + '.xml'
)

try {
  Import-Module Pester -MinimumVersion 5.0 -Force

  $configuration = New-PesterConfiguration
  $configuration.Run.Path = @($tests)
  $configuration.Run.PassThru = $true
  $configuration.Output.Verbosity = 'None'
  $configuration.CodeCoverage.Enabled = $true
  $configuration.CodeCoverage.Path = @($target)
  $configuration.CodeCoverage.OutputFormat = 'Cobertura'
  $configuration.CodeCoverage.OutputPath = $report
  $configuration.CodeCoverage.CoveragePercentTarget = 0

  $result = Invoke-Pester -Configuration $configuration
  $coverage = $result.CodeCoverage
  $analyzed = [int]$coverage.CommandsAnalyzedCount
  $executed = [int]$coverage.CommandsExecutedCount
  $missed = [int]$coverage.CommandsMissedCount
  $percent = [Math]::Round([double]$coverage.CoveragePercent, 1)

  $linePercent = $null
  $linesCovered = $null
  $linesValid = $null
  if (Test-Path -LiteralPath $report) {
    [xml]$xml = Get-Content -LiteralPath $report -Raw
    if ($xml.coverage) {
      $linesCovered = [int]$xml.coverage.'lines-covered'
      $linesValid = [int]$xml.coverage.'lines-valid'
      if ($linesValid -gt 0) {
        $linePercent = [Math]::Round(($linesCovered * 100.0 / $linesValid), 1)
      }
    }
  }

  [ordered]@{
    valid = ([int]$result.FailedCount -eq 0 -and $analyzed -gt 0)
    framework = "Pester $((Get-Module Pester).Version)"
    tests = [ordered]@{
      passed = [int]$result.PassedCount
      failed = [int]$result.FailedCount
      total = [int]$result.TotalCount
    }
    measured_scope = '.cursor/hooks/god-object-hook-common.ps1'
    coverage = [ordered]@{
      command_percent = $percent
      commands_executed = $executed
      commands_analyzed = $analyzed
      commands_missed = $missed
      line_percent = $linePercent
      lines_covered = $linesCovered
      lines_valid = $linesValid
    }
  } | ConvertTo-Json -Depth 8

  if ([int]$result.FailedCount -gt 0 -or $analyzed -eq 0) { exit 1 }
} finally {
  if (Test-Path -LiteralPath $report) {
    Remove-Item -LiteralPath $report -Force
  }
}
