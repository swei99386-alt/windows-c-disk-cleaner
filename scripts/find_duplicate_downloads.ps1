[CmdletBinding()]
param(
    [string[]]$ScanRoots,
    [int]$MinLargeFileMB = 200,
    [int]$RecentDays = 30,
    [switch]$Execute,
    [switch]$EmitJson
)

# Downloads/Desktop duplicate-package and large-recent-file hunter.
#
# Default behavior is report-only: nothing is deleted unless -Execute is passed,
# and even then only "redundant copy" files (name (1).ext / name - 副本.ext) whose
# original still exists in the same folder are removed. Large recent media and
# installers are always report-only; they are never auto-deleted, because a big
# recent file is usually something the user just downloaded on purpose.

$ErrorActionPreference = 'Stop'
$userProfile = [Environment]::GetFolderPath('UserProfile')

if (-not $ScanRoots -or $ScanRoots.Count -eq 0) {
    $ScanRoots = @(
        (Join-Path $userProfile 'Downloads'),
        (Join-Path $userProfile 'Desktop')
    )
}

function Convert-ToMB {
    param([Nullable[double]]$Bytes)
    if ($null -eq $Bytes) { return $null }
    return [math]::Round(($Bytes / 1MB), 1)
}

# Strip Windows/Quark style copy markers to recover the likely original name.
# Handles trailing " (1)", " - 副本", " - 副本 (2)", and English " - Copy".
function Get-OriginalName {
    param([string]$FileName)

    $ext = [System.IO.Path]::GetExtension($FileName)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)

    $isCopy = $false
    $changed = $true
    while ($changed) {
        $changed = $false
        # trailing numbered copy: "name (2)"
        $stripped = [System.Text.RegularExpressions.Regex]::Replace($base, '\s*\(\d+\)$', '')
        if ($stripped -ne $base) { $base = $stripped; $isCopy = $true; $changed = $true }
        # trailing copy word: "name - 副本" / "name - Copy" / "name - 拷贝"
        $stripped = [System.Text.RegularExpressions.Regex]::Replace($base, '\s*-\s*(副本|拷贝|Copy)$', '', 'IgnoreCase')
        if ($stripped -ne $base) { $base = $stripped; $isCopy = $true; $changed = $true }
    }

    return [pscustomobject]@{
        IsCopy       = $isCopy
        OriginalName = "$base$ext"
    }
}

$duplicates = New-Object System.Collections.Generic.List[object]
$largeRecent = New-Object System.Collections.Generic.List[object]
$missingRoots = New-Object System.Collections.Generic.List[string]
$cutoff = (Get-Date).AddDays(-1 * $RecentDays)
$minLargeBytes = [double]$MinLargeFileMB * 1MB

foreach ($root in $ScanRoots) {
    $rootPath = [string]$root
    if ([string]::IsNullOrWhiteSpace($rootPath)) { continue }
    if (-not (Test-Path -LiteralPath $rootPath)) {
        $missingRoots.Add($rootPath)
        continue
    }

    $files = Get-ChildItem -LiteralPath $rootPath -Force -File -Recurse -ErrorAction SilentlyContinue

    foreach ($file in $files) {
        $info = Get-OriginalName -FileName $file.Name

        if ($info.IsCopy) {
            $originalPath = Join-Path $file.DirectoryName $info.OriginalName
            $originalExists = Test-Path -LiteralPath $originalPath -PathType Leaf
            $duplicates.Add([pscustomobject]@{
                path            = $file.FullName
                size_mb         = Convert-ToMB $file.Length
                original_name   = $info.OriginalName
                original_exists = $originalExists
                last_write      = $file.LastWriteTime.ToString('yyyy-MM-dd')
                status          = 'plan'
                reason          = $null
            })
        }

        if ($file.Length -ge $minLargeBytes -and $file.LastWriteTime -ge $cutoff) {
            $largeRecent.Add([pscustomobject]@{
                path       = $file.FullName
                size_mb    = Convert-ToMB $file.Length
                last_write = $file.LastWriteTime.ToString('yyyy-MM-dd')
            })
        }
    }
}

# Only redundant copies whose original is still present are eligible for deletion,
# and only when the caller explicitly passes -Execute.
foreach ($dup in $duplicates) {
    if (-not $dup.original_exists) {
        $dup.status = 'skip'
        $dup.reason = 'no-original-found-keep-for-manual-review'
        continue
    }

    if (-not $Execute) {
        $dup.status = 'plan-delete'
        $dup.reason = 'original-exists-run-with-Execute-to-delete'
        continue
    }

    try {
        Remove-Item -LiteralPath $dup.path -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $dup.path) {
            $dup.status = 'failed'
            $dup.reason = 'path-still-exists'
        } else {
            $dup.status = 'deleted'
        }
    } catch {
        $dup.status = 'failed'
        $dup.reason = $_.Exception.Message
    }
}

$result = [pscustomobject]@{
    scan_roots          = $ScanRoots
    missing_roots       = $missingRoots
    recent_days         = $RecentDays
    min_large_file_mb   = $MinLargeFileMB
    executed            = [bool]$Execute
    duplicate_copies    = $duplicates | Sort-Object { $_.size_mb } -Descending
    large_recent_files  = $largeRecent | Sort-Object { $_.size_mb } -Descending
}

if ($EmitJson) {
    $result | ConvertTo-Json -Depth 5
} else {
    Write-Output "扫描目录: $($ScanRoots -join ', ')"
    if ($missingRoots.Count -gt 0) {
        Write-Output "找不到的目录(已跳过): $($missingRoots -join ', ')"
    }
    Write-Output ''
    Write-Output "== 重复副本(名字带 (1)(2)/副本) =="
    if ($duplicates.Count -eq 0) {
        Write-Output '  无'
    } else {
        $duplicates | Sort-Object { $_.size_mb } -Descending | Format-Table path, size_mb, original_exists, status, reason -AutoSize
    }
    Write-Output ''
    Write-Output "== 最近 $RecentDays 天的大文件(>= $MinLargeFileMB MB, 仅提示不自动删) =="
    if ($largeRecent.Count -eq 0) {
        Write-Output '  无'
    } else {
        $largeRecent | Sort-Object { $_.size_mb } -Descending | Format-Table path, size_mb, last_write -AutoSize
    }
}
