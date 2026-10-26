# Cursor afterFileEdit: queue one advisory warning for substantial file growth.
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::UTF8
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

try {
  $raw = [Console]::In.ReadToEnd()
  if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Output '{}'
    exit 0
  }

  $payload = $raw | ConvertFrom-Json
  . (Join-Path $PSScriptRoot 'god-object-hook-common.ps1')

  $root = Get-GodObjectWorkspaceRoot -Payload $payload
  $config = Read-GodObjectConfig -Root $root
  $relative = Get-GodObjectRelativePath -Path ([string]$payload.file_path) -Root $root
  if (-not $config -or -not $relative -or
      (Test-GodObjectExcluded -RelativePath $relative -Config $config)) {
    Write-Output '{}'
    exit 0
  }

  $statePath = Get-GodObjectStatePath -Root $root `
    -ConversationId ([string]$payload.conversation_id)
  $state = Read-GodObjectState -Path $statePath `
    -ConversationId ([string]$payload.conversation_id) `
    -GenerationId ([string]$payload.generation_id) `
    -ResetForGeneration

  $absolute = Join-Path $root ($relative.Replace('/', [IO.Path]::DirectorySeparatorChar))
  $current = Get-GodObjectLineCount -Path $absolute
  if (-not $state.baselines.Contains($relative)) {
    $baseline = Get-GodObjectGitBaseline -Root $root -RelativePath $relative
    if ($null -eq $baseline) {
      $baseline = [Math]::Max(0, $current - (Get-GodObjectEditDelta -Edits $payload.edits))
    }
    $state.baselines[$relative] = [int]$baseline
  }

  $baseline = [int]$state.baselines[$relative]
  if ($relative -notin @($state.growth_warned) -and
      (Test-GodObjectSubstantialGrowth -Baseline $baseline -Current $current `
        -Growth $config.growth)) {
    $scope = Read-GodObjectScope -Root $root
    $candidateNote = if (Test-GodObjectCandidate -RelativePath $relative `
        -Config $config -Scope $scope) {
      ' It is also listed in the active God Object analysis.'
    } else {
      ''
    }
    $added = $current - $baseline
    Add-GodObjectPendingMessage -State $state -Message `
      "File growth guard: $relative grew by $added lines from the Git baseline ($baseline -> $current).$candidateNote Reconsider whether the new responsibility belongs in this file; a justified large change remains allowed."
    $state.growth_warned = @($state.growth_warned + $relative)
  }

  Write-GodObjectState -Path $statePath -State $state
} catch {
  # Advisory post-edit accounting fails open.
}

Write-Output '{}'
exit 0
