[CmdletBinding()]
param(
    [string]$RootDrive = 'C',
    [string]$PreferredMoveDrive = 'E',
    [decimal]$MinSizeGB = 0.5,
    [int]$RecentDays = 30,
    [string]$TreeSizeReportPath,
    [switch]$EmitJson
)

$ErrorActionPreference = 'SilentlyContinue'

function Convert-ToGB {
    param([Nullable[double]]$Bytes)
    if ($null -eq $Bytes) { return $null }
    return [math]::Round(($Bytes / 1GB), 2)
}

function Get-ItemSizeBytes {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer) {
        return [double]$item.Length
    }

    $sum = (Get-ChildItem -LiteralPath $Path -Force -File -Recurse | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { return [double]0 }
    return [double]$sum
}

function New-AuditRow {
    param(
        [string]$Path,
        [string]$Category,
        [string]$WhyLarge,
        [string]$RecommendedAction,
        [string]$ActionClass,
        [string]$RiskLevel,
        [double]$EstimatedReclaimGB,
        [string]$TimeCost,
        [bool]$Rollbackable,
        [bool]$AdminRequired,
        [string]$BlockedBy
    )

    $sizeBytes = Get-ItemSizeBytes -Path $Path
    if ($null -eq $sizeBytes) { return $null }

    [pscustomobject]@{
        path                 = $Path
        size_gb              = Convert-ToGB $sizeBytes
        category             = $Category
        why_large            = $WhyLarge
        recommended_action   = $RecommendedAction
        action_class         = $ActionClass
        risk_level           = $RiskLevel
        estimated_reclaim_gb = $EstimatedReclaimGB
        time_cost            = $TimeCost
        rollbackable         = $Rollbackable
        admin_required       = $AdminRequired
        blocked_by           = $BlockedBy
    }
}

function Get-ProcessRowsForPaths {
    param(
        [string[]]$Paths,
        [string[]]$ProcessNames
    )

    $rows = @()
    if (-not $Paths -or -not $ProcessNames) { return $rows }

    $running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -in $ProcessNames }
    foreach ($proc in $running) {
        $procPath = $null
        try { $procPath = $proc.Path } catch {}
        foreach ($path in $Paths) {
            $rows += [pscustomobject]@{
                blocked_path = $path
                process_name = $proc.ProcessName
                pid          = $proc.Id
                process_path = $procPath
            }
        }
    }

    return $rows
}

function Get-TopLevelRanking {
    param([string]$DrivePath)

    $items = Get-ChildItem -LiteralPath $DrivePath -Force
    $rows = foreach ($item in $items) {
        $size = if ($item.PSIsContainer) {
            Get-ItemSizeBytes -Path $item.FullName
        } else {
            [double]$item.Length
        }

        [pscustomobject]@{
            path            = $item.FullName
            name            = $item.Name
            type            = if ($item.PSIsContainer) { 'directory' } else { 'file' }
            size_gb         = Convert-ToGB $size
            last_write_time = $item.LastWriteTime
        }
    }

    $rows | Sort-Object size_gb -Descending
}

function Get-RecentLargeItems {
    param(
        [object[]]$Objects,
        [datetime]$Since,
        [decimal]$MinGB
    )

    $rows = foreach ($object in $Objects) {
        if ($null -eq $object) { continue }

        $path = $object.path
        if (-not $path -or -not (Test-Path -LiteralPath $path)) { continue }

        $item = Get-Item -LiteralPath $path -Force
        $sizeGB = if ($null -ne $object.size_gb) { [decimal]$object.size_gb } else { Convert-ToGB (Get-ItemSizeBytes -Path $path) }

        if ($item.LastWriteTime -ge $Since -and $sizeGB -ge $MinGB) {
            [pscustomobject]@{
                path            = $path
                type            = if ($item.PSIsContainer) { 'directory' } else { 'file' }
                size_gb         = $sizeGB
                last_write_time = $item.LastWriteTime
            }
        }
    }

    $rows | Sort-Object last_write_time -Descending | Select-Object -First 40
}

$driveRoot = '{0}:\' -f $RootDrive.TrimEnd(':')
$drive = Get-PSDrive -Name $RootDrive.TrimEnd(':')
$userProfile = [Environment]::GetFolderPath('UserProfile')
$recentSince = (Get-Date).AddDays(-1 * $RecentDays)
$skillRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$policyPath = Join-Path $skillRoot 'config\auto-clean-policy.json'
$policy = $null
if (Test-Path -LiteralPath $policyPath) {
    $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
}

$treeSizeInput = $null
if ($TreeSizeReportPath -and (Test-Path -LiteralPath $TreeSizeReportPath)) {
    $extension = [System.IO.Path]::GetExtension($TreeSizeReportPath)
    if ($extension -eq '.csv') {
        $treeSizeInput = Import-Csv -LiteralPath $TreeSizeReportPath | Select-Object -First 30
    } else {
        $treeSizeInput = Get-Content -LiteralPath $TreeSizeReportPath | Select-Object -First 60
    }
}

$focusPaths = @(
    "$driveRoot`Users",
    "$driveRoot`Windows",
    "$driveRoot`Program Files",
    "$driveRoot`Program Files (x86)",
    "$driveRoot`ProgramData",
    $userProfile,
    (Join-Path $userProfile 'Downloads'),
    (Join-Path $userProfile 'Desktop'),
    (Join-Path $userProfile 'Documents')
)

$uvCachePath = Join-Path $userProfile 'AppData\Local\uv\cache'
$wpsPath = Join-Path $userProfile 'AppData\Local\Kingsoft\WPS Office'
$chromeUserDataPath = Join-Path $userProfile 'AppData\Local\Google\Chrome\User Data'
$edgeUserDataPath = Join-Path $userProfile 'AppData\Local\Microsoft\Edge\User Data'
$roamingNpmPath = Join-Path $userProfile 'AppData\Roaming\npm'
$windowsTempPath = "$env:SystemRoot\Temp"
$userTempPath = Join-Path $userProfile 'AppData\Local\Temp'
$pnpmStorePath = Join-Path $userProfile 'AppData\Local\pnpm\store'
$whisperCachePath = Join-Path $userProfile '.cache\whisper'
$geminiAntigravityBackupPath = Join-Path $userProfile '.gemini\antigravity-backup'
$geminiAntigravityIdePath = Join-Path $userProfile '.gemini\antigravity-ide'

$candidates = @(
    (New-AuditRow -Path (Join-Path $userProfile 'AppData\Local\npm-cache') -Category 'developer-cache' -WhyLarge 'npm package download cache accumulates duplicate package tarballs.' -RecommendedAction 'clear-cache' -ActionClass 'auto_clear' -RiskLevel 'low' -EstimatedReclaimGB 2.0 -TimeCost 'fast' -Rollbackable $false -AdminRequired $false -BlockedBy $null),
    (New-AuditRow -Path (Join-Path $userProfile '.bun\install\cache') -Category 'developer-cache' -WhyLarge 'bun install cache stores downloaded package payloads and native binaries.' -RecommendedAction 'clear-cache' -ActionClass 'auto_clear' -RiskLevel 'low' -EstimatedReclaimGB 1.0 -TimeCost 'fast' -Rollbackable $false -AdminRequired $false -BlockedBy $null),
    (New-AuditRow -Path (Join-Path $userProfile '.gemini\antigravity\browser_recordings') -Category 'ai-artifacts' -WhyLarge 'browser recordings and screenshots accumulate quickly and are not core application data.' -RecommendedAction 'clear-or-move' -ActionClass 'auto_clear' -RiskLevel 'low' -EstimatedReclaimGB 1.0 -TimeCost 'fast' -Rollbackable $false -AdminRequired $false -BlockedBy $null),
    (New-AuditRow -Path $windowsTempPath -Category 'system-temp' -WhyLarge 'Windows temporary files can accumulate after installs, updates, and failed cleanup runs.' -RecommendedAction 'clear-contents-after-confirmation' -ActionClass 'confirm_then_clear' -RiskLevel 'low' -EstimatedReclaimGB 2.5 -TimeCost 'fast' -Rollbackable $false -AdminRequired $true -BlockedBy 'manual-confirmation-required'),
    (New-AuditRow -Path $userTempPath -Category 'user-temp' -WhyLarge 'User temporary files are usually leftover installer and app scratch files.' -RecommendedAction 'clear-contents-after-confirmation' -ActionClass 'confirm_then_clear' -RiskLevel 'low' -EstimatedReclaimGB 0.5 -TimeCost 'fast' -Rollbackable $false -AdminRequired $false -BlockedBy 'manual-confirmation-required'),
    (New-AuditRow -Path $uvCachePath -Category 'developer-cache' -WhyLarge 'uv cache stores downloaded archives, build environments, and temporary Python environments that can be downloaded again.' -RecommendedAction 'clear-after-confirmation' -ActionClass 'confirm_then_clear' -RiskLevel 'low' -EstimatedReclaimGB 2.0 -TimeCost 'medium' -Rollbackable $false -AdminRequired $false -BlockedBy 'manual-confirmation-required'),
    (New-AuditRow -Path $whisperCachePath -Category 'ai-model-cache' -WhyLarge 'Whisper cache stores downloaded speech recognition models and can be downloaded again later.' -RecommendedAction 'clear-after-confirmation-if-unused' -ActionClass 'confirm_then_clear' -RiskLevel 'low' -EstimatedReclaimGB 0.5 -TimeCost 'fast' -Rollbackable $false -AdminRequired $false -BlockedBy 'manual-confirmation-required'),
    (New-AuditRow -Path $geminiAntigravityBackupPath -Category 'ai-tool-backup' -WhyLarge 'Antigravity backup folders are usually old copied tool state rather than active profile data.' -RecommendedAction 'clear-after-confirmation' -ActionClass 'confirm_then_clear' -RiskLevel 'low-to-medium' -EstimatedReclaimGB 0.6 -TimeCost 'fast' -Rollbackable $false -AdminRequired $false -BlockedBy 'manual-confirmation-required'),
    (New-AuditRow -Path $pnpmStorePath -Category 'developer-store' -WhyLarge 'pnpm store keeps shared package files for front-end projects and should be cleaned with pnpm store prune where possible.' -RecommendedAction 'pnpm-store-prune-or-manual-review' -ActionClass 'official_or_app_only' -RiskLevel 'medium' -EstimatedReclaimGB 1.8 -TimeCost 'medium' -Rollbackable $false -AdminRequired $false -BlockedBy 'tool-managed'),
    (New-AuditRow -Path (Join-Path $userProfile 'AppData\Local\Google\Chrome\User Data\OptGuideOnDeviceModel') -Category 'browser-cache' -WhyLarge 'Chrome local on-device model cache can grow to multiple gigabytes.' -RecommendedAction 'clear-cache' -ActionClass 'auto_clear' -RiskLevel 'low' -EstimatedReclaimGB 3.0 -TimeCost 'fast' -Rollbackable $false -AdminRequired $false -BlockedBy $null),
    (New-AuditRow -Path $chromeUserDataPath -Category 'browser-data' -WhyLarge 'Chrome keeps cache and profile data under User Data; only pure cache subdirectories are safe to clear after the browser fully exits.' -RecommendedAction 'close-browser-then-clear-cache-subdirs' -ActionClass 'close_process_then_clear' -RiskLevel 'medium' -EstimatedReclaimGB 4.0 -TimeCost 'medium' -Rollbackable $true -AdminRequired $false -BlockedBy 'browser-running'),
    (New-AuditRow -Path $edgeUserDataPath -Category 'browser-data' -WhyLarge 'Edge keeps cache and profile data under User Data; only pure cache subdirectories are safe to clear after the browser fully exits.' -RecommendedAction 'close-browser-then-clear-cache-subdirs' -ActionClass 'close_process_then_clear' -RiskLevel 'medium' -EstimatedReclaimGB 0.8 -TimeCost 'medium' -Rollbackable $true -AdminRequired $false -BlockedBy 'browser-running'),
    (New-AuditRow -Path $geminiAntigravityIdePath -Category 'ai-tool-runtime' -WhyLarge 'Antigravity IDE folders can contain active tool runtime data and should not be cleared without a separate decision.' -RecommendedAction 'inspect-before-delete' -ActionClass 'suggest_only' -RiskLevel 'medium' -EstimatedReclaimGB 0.6 -TimeCost 'medium' -Rollbackable $false -AdminRequired $false -BlockedBy 'manual-review-required'),
    (New-AuditRow -Path "$driveRoot`Windows\SoftwareDistribution" -Category 'system-update-cache' -WhyLarge 'Windows Update downloads and staging files can accumulate over time.' -RecommendedAction 'official-cleanup-only' -ActionClass 'official_or_app_only' -RiskLevel 'medium' -EstimatedReclaimGB 1.5 -TimeCost 'medium' -Rollbackable $false -AdminRequired $true -BlockedBy 'official-cleanup-required'),
    (New-AuditRow -Path (Join-Path $userProfile '.local\share\opencode') -Category 'tool-store' -WhyLarge 'Local snapshot and object packs for coding tools can be large and may be reused later.' -RecommendedAction 'audit-before-delete' -ActionClass 'suggest_only' -RiskLevel 'medium' -EstimatedReclaimGB 2.0 -TimeCost 'medium' -Rollbackable $false -AdminRequired $false -BlockedBy 'manual-review-required'),
    (New-AuditRow -Path $roamingNpmPath -Category 'global-cli' -WhyLarge 'Global npm packages keep full CLI installations and bundled binaries.' -RecommendedAction 'uninstall-unused-global-packages' -ActionClass 'official_or_app_only' -RiskLevel 'medium' -EstimatedReclaimGB 1.0 -TimeCost 'medium' -Rollbackable $true -AdminRequired $false -BlockedBy 'app-managed'),
    (New-AuditRow -Path $wpsPath -Category 'app-data' -WhyLarge 'WPS Office local data mixes cache, recent files, and app state, so it should be cleaned from inside the app or by uninstalling unused components.' -RecommendedAction 'clean-inside-wps-or-uninstall' -ActionClass 'official_or_app_only' -RiskLevel 'medium' -EstimatedReclaimGB 2.0 -TimeCost 'medium' -Rollbackable $true -AdminRequired $false -BlockedBy 'app-managed'),
    (New-AuditRow -Path "$driveRoot`$WINDOWS.~BT" -Category 'system-residual' -WhyLarge 'Upgrade staging files can remain after Windows feature updates.' -RecommendedAction 'official-cleanup-only' -ActionClass 'official_or_app_only' -RiskLevel 'low' -EstimatedReclaimGB 0.2 -TimeCost 'fast' -Rollbackable $false -AdminRequired $true -BlockedBy 'official-cleanup-required'),
    (New-AuditRow -Path (Join-Path $userProfile 'Documents\WeChat Files') -Category 'user-data' -WhyLarge 'WeChat file history stores images, videos, and transferred files.' -RecommendedAction 'move-to-preferred-drive' -ActionClass 'suggest_only' -RiskLevel 'low' -EstimatedReclaimGB 3.0 -TimeCost 'medium' -Rollbackable $true -AdminRequired $false -BlockedBy 'manual-review-required'),
    (New-AuditRow -Path (Join-Path $userProfile 'xwechat_files') -Category 'user-data' -WhyLarge 'Secondary WeChat data store can contain multiple account media archives.' -RecommendedAction 'move-to-preferred-drive' -ActionClass 'suggest_only' -RiskLevel 'low' -EstimatedReclaimGB 2.0 -TimeCost 'medium' -Rollbackable $true -AdminRequired $false -BlockedBy 'manual-review-required'),
    (New-AuditRow -Path (Join-Path $userProfile 'AppData\Local\wsl') -Category 'virtual-disk' -WhyLarge 'WSL keeps Linux distributions inside ext4.vhdx virtual disks on C: by default.' -RecommendedAction 'export-import-or-move-to-preferred-drive' -ActionClass 'suggest_only' -RiskLevel 'medium' -EstimatedReclaimGB 2.0 -TimeCost 'slow' -Rollbackable $true -AdminRequired $false -BlockedBy 'manual-review-required')
) | Where-Object { $null -ne $_ -and $_.size_gb -ge $MinSizeGB }

$topLevelRankings = @(Get-TopLevelRanking -DrivePath $driveRoot)
$recentSeed = @($topLevelRankings + $candidates)

$report = [pscustomobject]@{
    generated_at         = Get-Date
    root_drive           = $driveRoot
    preferred_move_drive = '{0}:\' -f $PreferredMoveDrive.TrimEnd(':')
    drive_summary        = [pscustomobject]@{
        total_gb = Convert-ToGB ([double]($drive.Used + $drive.Free))
        used_gb  = Convert-ToGB ([double]$drive.Used)
        free_gb  = Convert-ToGB ([double]$drive.Free)
    }
    tree_size_input      = $treeSizeInput
    top_level_rankings   = @($topLevelRankings | Select-Object -First 20)
    root_large_files     = @(Get-ChildItem -LiteralPath $driveRoot -Force -File | Where-Object { $_.Length -ge 500MB } | ForEach-Object {
        [pscustomobject]@{
            path            = $_.FullName
            size_gb         = Convert-ToGB ([double]$_.Length)
            last_write_time = $_.LastWriteTime
        }
    } | Sort-Object size_gb -Descending)
    recent_large_items   = @(Get-RecentLargeItems -Objects $recentSeed -Since $recentSince -MinGB $MinSizeGB)
    focus_directory_sizes = @($focusPaths | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object {
        $focusPath = $_
        [pscustomobject]@{
            path    = $focusPath
            size_gb = if ($focusPath.StartsWith($driveRoot) -and $focusPath.TrimEnd('\').Split('\').Count -eq 2) {
                ($topLevelRankings | Where-Object { $_.path -eq $focusPath } | Select-Object -First 1).size_gb
            } else {
                Convert-ToGB (Get-ItemSizeBytes -Path $focusPath)
            }
        }
    } | Sort-Object size_gb -Descending)
    candidates           = @($candidates | Sort-Object @{ Expression = 'estimated_reclaim_gb'; Descending = $true }, @{ Expression = 'size_gb'; Descending = $true })
    move_candidates      = @($candidates | Where-Object { $_.recommended_action -eq 'move-to-preferred-drive' -or $_.recommended_action -eq 'export-import-or-move-to-preferred-drive' })
    low_risk_candidates  = @($candidates | Where-Object {
        $_.risk_level -eq 'low' -and $_.recommended_action -in @('clear-cache', 'clear-or-move')
    })
    auto_clear_candidates = @($candidates | Where-Object { $_.action_class -eq 'auto_clear' })
    confirm_then_clear_candidates = @($candidates | Where-Object { $_.action_class -eq 'confirm_then_clear' })
    close_process_then_clear_candidates = @($candidates | Where-Object { $_.action_class -eq 'close_process_then_clear' })
    official_or_app_only_candidates = @($candidates | Where-Object { $_.action_class -eq 'official_or_app_only' })
    never_touch_candidates = @(
        foreach ($path in @($policy.never_touch_roots)) {
            $sizeBytes = Get-ItemSizeBytes -Path $path
            if ($null -eq $sizeBytes) { continue }
            [pscustomobject]@{
                path = $path
                size_gb = Convert-ToGB $sizeBytes
                action_class = 'never_touch'
                blocked_by = 'never-touch'
            }
        }
    )
    blocking_processes = @(
        (Get-ProcessRowsForPaths -Paths @($chromeUserDataPath) -ProcessNames @('chrome'))
        (Get-ProcessRowsForPaths -Paths @($edgeUserDataPath) -ProcessNames @('msedge'))
        (Get-ProcessRowsForPaths -Paths @($uvCachePath) -ProcessNames @('uv', 'uvx', 'python'))
    )
}

if ($EmitJson) {
    $report | ConvertTo-Json -Depth 6
} else {
    $report
}
