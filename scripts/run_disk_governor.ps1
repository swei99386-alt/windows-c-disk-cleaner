[CmdletBinding()]
param(
    [ValidateSet('audit-only', 'report-only', 'safe-clean', 'confirmed-clean', 'project-work-clean', 'closing-report', 'deep-closing-report')]
    [string]$Mode = 'report-only',
    [string]$ReportPath,
    [string[]]$ProjectWorkPath,
    [string]$PolicyPath,
    [switch]$EmitJson
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$auditScript = Join-Path $scriptRoot 'audit_windows_disk.ps1'
$runnerScript = Join-Path $scriptRoot 'run_from_treesize.ps1'
$closingScript = Join-Path $scriptRoot 'write_closing_report.ps1'
$confirmedCleanScript = Join-Path $scriptRoot 'cleanup_confirmed_safe.ps1'

if ($Mode -eq 'audit-only') {
    $args = @('-ExecutionPolicy', 'Bypass', '-File', $auditScript, '-EmitJson')
    $result = powershell @args | ConvertFrom-Json
} elseif ($Mode -eq 'closing-report' -or $Mode -eq 'deep-closing-report') {
    $args = @('-ExecutionPolicy', 'Bypass', '-File', $closingScript)
    if ($Mode -eq 'deep-closing-report') {
        $args += '-DeepRootScan'
    }
    $args += '-EmitJson'
    $result = powershell @args | ConvertFrom-Json
} elseif ($Mode -eq 'confirmed-clean' -or $Mode -eq 'project-work-clean') {
    $args = @(
        '-ExecutionPolicy', 'Bypass',
        '-File', $confirmedCleanScript,
        '-Execute',
        '-EmitJson'
    )
    if ($Mode -eq 'confirmed-clean') {
        $args += @('-IncludeConfirmedCaches', '-IncludeBrowserCaches')
    }
    if ($ProjectWorkPath) {
        foreach ($path in $ProjectWorkPath) {
            $args += @('-ProjectWorkPath', $path)
        }
    }
    if ($PolicyPath) {
        $args += @('-PolicyPath', $PolicyPath)
    }
    $result = powershell @args | ConvertFrom-Json
} else {
    $args = @('-ExecutionPolicy', 'Bypass', '-File', $runnerScript)
    if ($ReportPath) {
        $args += @('-ReportPath', $ReportPath)
    }
    if ($PolicyPath) {
        $args += @('-PolicyPath', $PolicyPath)
    }
    if ($Mode -eq 'safe-clean') {
        $args += '-Execute'
    }
    $args += '-EmitJson'
    $result = powershell @args | ConvertFrom-Json
}

if ($EmitJson) {
    $result | ConvertTo-Json -Depth 10
} else {
    $result
}
