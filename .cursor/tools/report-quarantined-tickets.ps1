param(
  [string]$Root = (Get-Location).Path,
  [string[]]$OpenIssue,
  [switch]$Json
)

# Reports rule IDs and locations only. Never reads or emits ticket payload text.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

$stateDir = Join-Path $Root '.cursor/hooks/state'
$tickets = [Collections.Generic.List[object]]::new()

foreach ($file in @(Get-ChildItem -LiteralPath $stateDir -Filter 'ticket-*.scan.json' `
    -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
  try {
    $state = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8 |
      ConvertFrom-Json
    if ([string]$state.status -notin @('suspicious', 'quarantined')) { continue }
    if ($OpenIssue -and [string]$state.ticket -notin @($OpenIssue)) { continue }

    if ([int]$state.schema_version -lt 2) {
      $tickets.Add([ordered]@{
        ticket = [string]$state.ticket
        status = 'rescan_required'
        work_status = 'unresolved'
        implementation = 'unknown'
        pull_request = 'unknown'
        reasons = @([ordered]@{ rule = 'stale-scan-state'; location = 'ticket' })
        required_action = 'Rescan the full ticket before claiming work or delivery status.'
        scanned_at = [string]$state.scanned_at
      })
      continue
    }

    $reasons = @($state.findings | ForEach-Object {
      [ordered]@{
        rule = [string]$_.rule
        location = [string]$_.location
      }
    })
    $tickets.Add([ordered]@{
      ticket = [string]$state.ticket
      status = [string]$state.status
      work_status = 'not_done'
      implementation = 'blocked'
      pull_request = 'none'
      reasons = $reasons
      required_action = if ($state.required_action) {
        [string]$state.required_action
      } else {
        'Human review and explicit approval of sanitized requirements are required.'
      }
      scanned_at = [string]$state.scanned_at
    })
  } catch {
    $ticket = $file.BaseName -replace '^ticket-', '' -replace '\.scan$', ''
    $tickets.Add([ordered]@{
      ticket = $ticket
      status = 'quarantined'
      work_status = 'not_done'
      implementation = 'blocked'
      pull_request = 'none'
      reasons = @([ordered]@{ rule = 'scan-state-unreadable'; location = 'ticket' })
      required_action = 'Repair and rerun the ticket scan.'
      scanned_at = $null
    })
  }
}

if ($Json) {
  @($tickets) | ConvertTo-Json -Depth 6
  exit 0
}

foreach ($ticket in $tickets) {
  $reasonText = @($ticket.reasons | ForEach-Object {
    "$($_.rule) at $($_.location)"
  }) -join '; '
  if ($ticket.status -eq 'rescan_required') {
    Write-Output "Ticket #$($ticket.ticket) status is unresolved. $reasonText. $($ticket.required_action)"
  } else {
    Write-Output "Ticket #$($ticket.ticket) is not done. $($ticket.status): $reasonText. No implementation or PR exists. $($ticket.required_action)"
  }
}
