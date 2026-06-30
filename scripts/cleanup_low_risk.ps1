[CmdletBinding()]
param(
    [switch]$Execute,
    [switch]$IncludeBrowserCaches,
    [switch]$IncludeConfirmedCaches,
    [switch]$StopBrowserProcesses,
    [string]$PolicyPath,
    [switch]$EmitJson
)

$ErrorActionPreference = 'Stop'
$userProfile = [Environment]::GetFolderPath('UserProfile')
$skillRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not $PolicyPath) {
    $PolicyPath = Join-Path $skillRoot 'config\auto-clean-policy.json'
}

function Convert-ToGB {
    param([Nullable[double]]$Bytes)
    if ($null -eq $Bytes) { return $null }
    return [math]::Round(($Bytes / 1GB), 2)
}

function Get-DirSizeBytes {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $sum = (Get-ChildItem -LiteralPath $Path -Force -File -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { return [double]0 }
    return [double]$sum
}

function Load-Policy {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Policy file not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Test-PathInRoots {
    param(
        [string]$Path,
        [object[]]$Roots
    )

    foreach ($root in $Roots) {
        $rootPath = [string]$root
        if ([string]::IsNullOrWhiteSpace($rootPath)) { continue }
        if ($Path -eq $rootPath -or $Path.StartsWith($rootPath + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Remove-DirectorySafe {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ status = 'missing'; reason = 'path-not-found' }
    }

    try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $Path) {
            return [pscustomobject]@{ status = 'failed'; reason = 'path-still-exists' }
        }

        return [pscustomobject]@{ status = 'deleted'; reason = $null }
    } catch {
        $message = $_.Exception.Message
        if ($message -match 'being used by another process' -or $message -match 'Access to the path' -or $message -match 'cannot access the file') {
            return [pscustomobject]@{ status = 'skipped-in-use'; reason = $message }
        }

        return [pscustomobject]@{ status = 'failed'; reason = $message }
    }
}

function Clear-DirectoryContentsSafe {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ status = 'missing'; reason = 'path-not-found' }
    }

    try {
        Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop | Remove-Item -Recurse -Force -ErrorAction Stop
        return [pscustomobject]@{ status = 'cleared'; reason = $null }
    } catch {
        $message = $_.Exception.Message
        if ($message -match 'being used by another process' -or $message -match 'Access to the path' -or $message -match 'cannot access the file') {
            return [pscustomobject]@{ status = 'skipped-in-use'; reason = $message }
        }

        return [pscustomobject]@{ status = 'failed'; reason = $message }
    }
}

function Get-BrowserCacheTargets {
    param(
        [string]$BasePath,
        [string[]]$DirectoryNames
    )

    if (-not (Test-Path -LiteralPath $BasePath)) { return @() }

    try {
        Get-ChildItem -LiteralPath $BasePath -Force -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -in $DirectoryNames
        } | Select-Object -ExpandProperty FullName
    } catch {
        @()
    }
}

$policy = Load-Policy -Path $PolicyPath
$browserDirectoryNames = @($policy.browser_cache_dir_names)
$neverTouchRoots = @($policy.never_touch_roots)
$browserRunning = [bool](Get-Process chrome, msedge -ErrorAction SilentlyContinue)

$targets = @(
    [pscustomobject]@{ name = 'npm-cache'; path = (Join-Path $userProfile 'AppData\Local\npm-cache'); type = 'directory'; requires_browser_stop = $false; skip_size_when_running = $false; allow_under_never_touch = $false },
    [pscustomobject]@{ name = 'bun-cache'; path = (Join-Path $userProfile '.bun\install\cache'); type = 'directory'; requires_browser_stop = $false; skip_size_when_running = $false; allow_under_never_touch = $false },
    [pscustomobject]@{ name = 'gemini-browser-recordings'; path = (Join-Path $userProfile '.gemini\antigravity\browser_recordings'); type = 'directory'; requires_browser_stop = $false; skip_size_when_running = $false; allow_under_never_touch = $false }
)

foreach ($path in @($policy.auto_clear_paths)) {
    if ([string]::IsNullOrWhiteSpace([string]$path)) { continue }
    $targets += [pscustomobject]@{ name = 'policy-auto-clear'; path = [string]$path; type = 'directory'; requires_browser_stop = $false; skip_size_when_running = $false; allow_under_never_touch = $false }
}

if ($IncludeConfirmedCaches) {
    $targets += @(
        [pscustomobject]@{ name = 'windows-temp'; path = "$env:SystemRoot\Temp"; type = 'directory_contents'; requires_browser_stop = $false; skip_size_when_running = $false; allow_under_never_touch = $true },
        [pscustomobject]@{ name = 'user-temp'; path = (Join-Path $userProfile 'AppData\Local\Temp'); type = 'directory_contents'; requires_browser_stop = $false; skip_size_when_running = $false; allow_under_never_touch = $false },
        [pscustomobject]@{ name = 'uv-cache-confirmed'; path = (Join-Path $userProfile 'AppData\Local\uv\cache'); type = 'directory'; requires_browser_stop = $false; skip_size_when_running = $false; allow_under_never_touch = $false },
        [pscustomobject]@{ name = 'whisper-cache-confirmed'; path = (Join-Path $userProfile '.cache\whisper'); type = 'directory'; requires_browser_stop = $false; skip_size_when_running = $false; allow_under_never_touch = $false },
        [pscustomobject]@{ name = 'gemini-antigravity-backup-confirmed'; path = (Join-Path $userProfile '.gemini\antigravity-backup'); type = 'directory'; requires_browser_stop = $false; skip_size_when_running = $false; allow_under_never_touch = $false }
    )
}

if ($IncludeBrowserCaches) {
    $targets += [pscustomobject]@{ name = 'chrome-opt-guide-model'; path = (Join-Path $userProfile 'AppData\Local\Google\Chrome\User Data\OptGuideOnDeviceModel'); type = 'directory'; requires_browser_stop = $true; skip_size_when_running = ($browserRunning -and $Execute -and -not $StopBrowserProcesses); allow_under_never_touch = $false }

    $cacheRoots = @($policy.cache_scan_roots)
    if (-not $cacheRoots -or $cacheRoots.Count -eq 0) {
        $cacheRoots = @(
            (Join-Path $userProfile 'AppData\Local\Google\Chrome\User Data'),
            (Join-Path $userProfile 'AppData\Local\Microsoft\Edge\User Data')
        )
    }

    foreach ($root in $cacheRoots) {
        $rootPath = [string]$root
        if ([string]::IsNullOrWhiteSpace($rootPath)) { continue }
        $requiresBrowserStop = $rootPath -like '*\Google\Chrome\User Data' -or $rootPath -like '*\Microsoft\Edge\User Data'
        if ($requiresBrowserStop -and $browserRunning -and $Execute -and -not $StopBrowserProcesses) {
            $targets += [pscustomobject]@{ name = 'browser-cache-root'; path = $rootPath; type = 'directory'; requires_browser_stop = $true; skip_size_when_running = $true; allow_under_never_touch = $false }
            continue
        }
        foreach ($path in (Get-BrowserCacheTargets -BasePath $rootPath -DirectoryNames $browserDirectoryNames)) {
            $targets += [pscustomobject]@{ name = 'cache-scan'; path = $path; type = 'directory'; requires_browser_stop = $requiresBrowserStop; skip_size_when_running = $false; allow_under_never_touch = $false }
        }
    }
}

if ($browserRunning -and $IncludeBrowserCaches -and $Execute -and $StopBrowserProcesses) {
    Get-Process chrome, msedge -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

$results = foreach ($target in $targets | Sort-Object path -Unique) {
    $beforeBytes = if ($target.skip_size_when_running) { $null } else { Get-DirSizeBytes -Path $target.path }
    $status = 'plan'
    $reason = $null

    if ($target.skip_size_when_running) {
        $status = 'skipped-in-use'
        $reason = 'browser-running-scan-skipped'
    } elseif ($null -eq $beforeBytes) {
        $status = 'missing'
        $reason = 'path-not-found'
    } elseif (-not $target.allow_under_never_touch -and (Test-PathInRoots -Path $target.path -Roots $neverTouchRoots)) {
        $status = 'failed'
        $reason = 'path-blocked-by-policy'
    } elseif ($Execute) {
        if ($target.requires_browser_stop -and [bool](Get-Process chrome, msedge -ErrorAction SilentlyContinue)) {
            $status = 'skipped-in-use'
            $reason = 'browser-running'
        } else {
            $removeResult = if ($target.type -eq 'directory_contents') {
                Clear-DirectoryContentsSafe -Path $target.path
            } else {
                Remove-DirectorySafe -Path $target.path
            }
            $status = $removeResult.status
            $reason = $removeResult.reason
        }
    }

    $afterBytes = if ($target.skip_size_when_running) { $null } else { Get-DirSizeBytes -Path $target.path }

    [pscustomobject]@{
        name      = $target.name
        path      = $target.path
        before_gb = Convert-ToGB $beforeBytes
        after_gb  = Convert-ToGB $afterBytes
        freed_gb  = if ($null -ne $beforeBytes -and $null -ne $afterBytes) { Convert-ToGB ($beforeBytes - $afterBytes) } elseif ($null -ne $beforeBytes -and $status -eq 'deleted') { Convert-ToGB $beforeBytes } else { $null }
        status    = $status
        reason    = $reason
    }
}

if ($EmitJson) {
    $results | ConvertTo-Json -Depth 4
} else {
    $results
}
