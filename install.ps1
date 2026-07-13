[CmdletBinding()]
param(
    [ValidateSet('All', 'ClaudeCode', 'Codex', 'Antigravity')]
    [string[]]$Target = @('All'),
    [ValidateSet('Auto', 'Junction', 'Copy')]
    [string]$InstallMode = 'Auto',
    [switch]$Force,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path $PSScriptRoot).Path
$name = 'windows-c-disk-cleaner'
$targets = [ordered]@{
    ClaudeCode   = [IO.Path]::Combine($env:USERPROFILE, '.claude', 'skills', $name)
    Codex        = [IO.Path]::Combine($env:USERPROFILE, '.codex', 'skills', $name)
    Antigravity  = [IO.Path]::Combine($env:USERPROFILE, '.gemini', 'config', 'skills', $name)
}
if ($Target -contains 'All') { $selected = @($targets.Keys) } else { $selected = $Target }
$results = @()

function Get-PathKind([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return 'missing' }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.LinkType) { return $item.LinkType }
    return 'directory'
}

function Add-Result($assistant, $status, $path, $detail) {
    $script:results += [pscustomobject]@{ Target=$assistant; Status=$status; Path=$path; Detail=$detail }
}

foreach ($assistant in $selected) {
    $destination = $targets[$assistant]
    try {
        $parent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $parent)) {
            if ($WhatIf) { Add-Result $assistant 'skipped' $destination 'would_create_parent'; continue }
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        if (Test-Path -LiteralPath $destination) {
            $resolved = try { (Resolve-Path -LiteralPath $destination -ErrorAction Stop).Path } catch { $null }
            if ($resolved -eq $source) { Add-Result $assistant 'already_installed' $destination 'points_to_current_project'; continue }
            $kind = Get-PathKind $destination
            if (-not $Force) { Add-Result $assistant ($(if ($kind -eq 'directory') { 'conflict' } else { 'conflict' })) $destination "existing_$kind"; continue }
            $backup = "$destination.backup-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
            if ($WhatIf) { Add-Result $assistant 'skipped' $destination "would_backup_to_$backup"; continue }
            Move-Item -LiteralPath $destination -Destination $backup -ErrorAction Stop
        }
        if ($WhatIf) { Add-Result $assistant 'skipped' $destination "would_install_$InstallMode"; continue }
        $mode = $InstallMode
        if ($mode -in @('Auto','Junction')) {
            try { New-Item -ItemType Junction -Path $destination -Target $source -ErrorAction Stop | Out-Null; Add-Result $assistant 'installed' $destination 'junction'; continue } catch { if ($InstallMode -eq 'Junction') { throw } }
        }
        if ($mode -eq 'Auto') {
            try { New-Item -ItemType SymbolicLink -Path $destination -Target $source -ErrorAction Stop | Out-Null; Add-Result $assistant 'installed' $destination 'symbolic_link'; continue } catch { }
        }
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force -ErrorAction Stop
        Add-Result $assistant 'installed' $destination 'copy'
    } catch { Add-Result $assistant 'failed' $destination $_.Exception.Message }
}

$results | Format-Table Target, Status, Path -AutoSize
if ($results.Status -contains 'failed' -or $results.Status -contains 'conflict') { exit 1 }
