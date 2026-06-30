[CmdletBinding()]
param(
    [string]$ReportPath,
    [string]$PolicyPath,
    [switch]$Execute,
    [switch]$EmitJson
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptRoot

if (-not $PolicyPath) {
    $PolicyPath = Join-Path $skillRoot 'config\auto-clean-policy.json'
}

$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
$readTreeScript = Join-Path $scriptRoot 'read_treesize_input.ps1'
$auditScript = Join-Path $scriptRoot 'audit_windows_disk.ps1'
$cleanupScript = Join-Path $scriptRoot 'cleanup_low_risk.ps1'

$treeSummary = $null
if ($ReportPath) {
    $treeSummary = powershell -ExecutionPolicy Bypass -File $readTreeScript -ReportPath $ReportPath -MinSizeGB $policy.min_report_size_gb -EmitJson | ConvertFrom-Json
}

$audit = powershell -ExecutionPolicy Bypass -File $auditScript -EmitJson | ConvertFrom-Json

$cleanupArgs = @(
    '-ExecutionPolicy', 'Bypass',
    '-File', $cleanupScript,
    '-IncludeBrowserCaches',
    '-PolicyPath', $PolicyPath,
    '-EmitJson'
)

if ($Execute) {
    $cleanupArgs += '-Execute'
    if ($policy.allow_process_stop) {
        $cleanupArgs += '-StopBrowserProcesses'
    }
}

$cleanup = powershell @cleanupArgs | ConvertFrom-Json

$suggestOnly = @($audit.candidates | Where-Object { $_.action_class -eq 'suggest_only' })
$confirmThenClear = @($audit.candidates | Where-Object { $_.action_class -eq 'confirm_then_clear' })
$closeProcessThenClear = @($audit.close_process_then_clear_candidates)
$officialOrAppOnly = @($audit.official_or_app_only_candidates)
$neverTouch = @($audit.never_touch_candidates)
if ($treeSummary -and $treeSummary.heat_paths) {
    $heatPaths = @($treeSummary.heat_paths)
    $suggestOnly = @(
        $suggestOnly | Where-Object {
            $candidatePath = [string]$_.path
            ($heatPaths | Where-Object { $candidatePath -eq $_ -or $candidatePath.StartsWith($_ + '\') -or $_.StartsWith($candidatePath + '\') }) | Select-Object -First 1
        }
    )
    $closeProcessThenClear = @(
        $closeProcessThenClear | Where-Object {
            $candidatePath = [string]$_.path
            ($heatPaths | Where-Object { $candidatePath -eq $_ -or $candidatePath.StartsWith($_ + '\') -or $_.StartsWith($candidatePath + '\') }) | Select-Object -First 1
        }
    )
    $confirmThenClear = @(
        $confirmThenClear | Where-Object {
            $candidatePath = [string]$_.path
            ($heatPaths | Where-Object { $candidatePath -eq $_ -or $candidatePath.StartsWith($_ + '\') -or $_.StartsWith($candidatePath + '\') }) | Select-Object -First 1
        }
    )
    $officialOrAppOnly = @(
        $officialOrAppOnly | Where-Object {
            $candidatePath = [string]$_.path
            ($heatPaths | Where-Object { $candidatePath -eq $_ -or $candidatePath.StartsWith($_ + '\') -or $_.StartsWith($candidatePath + '\') }) | Select-Object -First 1
        }
    )
    $neverTouch = @(
        $neverTouch | Where-Object {
            $candidatePath = [string]$_.path
            ($heatPaths | Where-Object { $candidatePath -eq $_ -or $candidatePath.StartsWith($_ + '\') -or $_.StartsWith($candidatePath + '\') }) | Select-Object -First 1
        }
    )
}

$blockingProcesses = @($audit.blocking_processes)
if ($treeSummary -and $treeSummary.heat_paths) {
    $heatPaths = @($treeSummary.heat_paths)
    $blockingProcesses = @(
        $blockingProcesses | Where-Object {
            $blockedPath = [string]$_.blocked_path
            ($heatPaths | Where-Object { $blockedPath -eq $_ -or $blockedPath.StartsWith($_ + '\') -or $_.StartsWith($blockedPath + '\') }) | Select-Object -First 1
        }
    )
}

$result = [pscustomobject]@{
    mode = if ($Execute) { 'safe-clean' } else { 'report-only' }
    report_path = $ReportPath
    tree_size_summary = $treeSummary
    drive_summary = $audit.drive_summary
    cleaned = @($cleanup | Where-Object { $_.status -in @('deleted', 'cleared') })
    skipped_in_use = @($cleanup | Where-Object { $_.status -eq 'skipped-in-use' })
    failed = @($cleanup | Where-Object { $_.status -eq 'failed' })
    missing = @($cleanup | Where-Object { $_.status -eq 'missing' })
    confirm_then_clear = $confirmThenClear
    close_process_then_clear = $closeProcessThenClear
    blocking_processes = $blockingProcesses
    suggest_only_large_items = $suggestOnly
    official_or_app_only = $officialOrAppOnly
    never_touch = $neverTouch
}

if ($EmitJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    $result
}
