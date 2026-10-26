param(
  [Parameter(Mandatory = $true)]
  [string] $Prompt,
  [string] $Purpose = 'skill_factory_loop'
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/write-prompt-log.ps1"

Write-PromptLog -Record @{
  event   = 'loop_tick'
  source  = 'factory-loop'
  purpose = $Purpose
  prompt  = $Prompt
}
