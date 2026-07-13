[CmdletBinding()]
param(
    [switch]$Execute,
    [switch]$IncludeConfirmedCaches,
    [switch]$IncludeBrowserCaches,
    [string[]]$ProjectWorkPath,
    [string]$PolicyPath,
    [switch]$EmitJson
)

$ErrorActionPreference = 'Stop'
$userProfile = [Environment]::GetFolderPath('UserProfile')
$skillRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'lib\PolicyHelpers.ps1')

if (-not $PolicyPath) {
    $PolicyPath = Join-Path $skillRoot 'config\auto-clean-policy.json'
}

function Convert-ToGB {
    param([Nullable[double]]$Bytes)
    if ($null -eq $Bytes) { return $null }
    return [math]::Round(($Bytes / 1GB), 2)
}

function Get-DriveState {
    param([string]$Letter)
    $name = ($Letter -replace '[:\\]', '').Substring(0, 1).ToUpperInvariant()
    $drive = Get-PSDrive -Name $name -ErrorAction SilentlyContinue
    if (-not $drive) { return $null }

    [pscustomobject]@{
        drive    = "$name`:"
        total_gb = Convert-ToGB ([double]($drive.Used + $drive.Free))
        used_gb  = Convert-ToGB ([double]$drive.Used)
        free_gb  = Convert-ToGB ([double]$drive.Free)
    }
}

function Get-DirSizeBytes {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer) { return [double]$item.Length }

    $sum = (Get-ChildItem -LiteralPath $Path -Force -File -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { return [double]0 }
    return [double]$sum
}

function Add-Result {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Status,
        [Nullable[double]]$BeforeBytes,
        [Nullable[double]]$AfterBytes,
        [string]$Reason
    )

    $script:results += [pscustomobject]@{
        name      = $Name
        path      = $Path
        status    = $Status
        before_gb = Convert-ToGB $BeforeBytes
        after_gb  = Convert-ToGB $AfterBytes
        freed_gb  = if ($null -ne $BeforeBytes -and $null -ne $AfterBytes) {
            Convert-ToGB ($BeforeBytes - $AfterBytes)
        } elseif ($null -ne $BeforeBytes -and $Status -eq 'deleted') {
            Convert-ToGB $BeforeBytes
        } else {
            $null
        }
        reason    = $Reason
    }
}

function Test-SafeProjectWorkPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $false }

    $resolved = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
    $codexRoot = Join-Path $userProfile 'Documents\Codex'
    $codexRoot = (Resolve-Path -LiteralPath $codexRoot -ErrorAction SilentlyContinue).Path
    if (-not $codexRoot) { return $false }

    if (-not $resolved.StartsWith($codexRoot.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    if (-not $resolved.EndsWith('\work', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }

    $projectRoot = Split-Path -Parent $resolved
    $markers = @('package.json', '.git', 'pyproject.toml', 'android', 'vite.config.ts')
    foreach ($marker in $markers) {
        if (Test-Path -LiteralPath (Join-Path $projectRoot $marker)) { return $true }
    }

    return $false
}

function Remove-WholePathSafe {
    param([string]$Name, [string]$Path)
    $before = Get-DirSizeBytes -Path $Path
    if ($null -eq $before -and -not (Test-Path -LiteralPath $Path)) {
        Add-Result -Name $Name -Path $Path -Status 'missing' -BeforeBytes $null -AfterBytes $null -Reason 'path-not-found'
        return
    }

    if (-not $Execute) {
        Add-Result -Name $Name -Path $Path -Status 'plan' -BeforeBytes $before -AfterBytes $before -Reason $null
        return
    }

    try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        $after = Get-DirSizeBytes -Path $Path
        Add-Result -Name $Name -Path $Path -Status 'deleted' -BeforeBytes $before -AfterBytes $after -Reason $null
    } catch {
        $after = Get-DirSizeBytes -Path $Path
        $status = if ($null -ne $after -and $after -lt $before) { 'partial' } else { 'skipped-in-use' }
        Add-Result -Name $Name -Path $Path -Status $status -BeforeBytes $before -AfterBytes $after -Reason $_.Exception.Message
    }
}

function Clear-DirectoryContentsSafe {
    param([string]$Name, [string]$Path)
    $before = Get-DirSizeBytes -Path $Path
    if ($null -eq $before -and -not (Test-Path -LiteralPath $Path)) {
        Add-Result -Name $Name -Path $Path -Status 'missing' -BeforeBytes $null -AfterBytes $null -Reason 'path-not-found'
        return
    }

    if (-not $Execute) {
        Add-Result -Name $Name -Path $Path -Status 'plan' -BeforeBytes $before -AfterBytes $before -Reason $null
        return
    }

    try {
        $children = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop)
    } catch {
        Add-Result -Name $Name -Path $Path -Status 'failed' -BeforeBytes $before -AfterBytes $before -Reason $_.Exception.Message
        return
    }

    $hadFailure = $false
    $reasons = @()
    foreach ($child in $children) {
        try {
            Remove-Item -LiteralPath $child.FullName -Recurse -Force -ErrorAction Stop
        } catch {
            $hadFailure = $true
            if ($reasons -notcontains $_.Exception.Message) { $reasons += $_.Exception.Message }
        }
    }

    $after = Get-DirSizeBytes -Path $Path
    if ($hadFailure) {
        $status = if ($after -lt $before) { 'partial' } else { 'skipped-in-use' }
        Add-Result -Name $Name -Path $Path -Status $status -BeforeBytes $before -AfterBytes $after -Reason ($reasons -join ' | ')
    } else {
        Add-Result -Name $Name -Path $Path -Status 'cleared' -BeforeBytes $before -AfterBytes $after -Reason $null
    }
}

function Get-BrowserCacheTargets {
    param([string]$Root)
    $names = @('Cache', 'Code Cache', 'GPUCache', 'DawnCache', 'GrShaderCache', 'ShaderCache', 'Media Cache', 'CacheStorage', 'Crashpad', 'component_crx_cache')
    $targets = @()
    if (-not (Test-Path -LiteralPath $Root)) { return $targets }

    $dirs = Get-ChildItem -LiteralPath $Root -Force -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -in $names }
    foreach ($dir in $dirs) {
        if ($targets -notcontains $dir.FullName) { $targets += $dir.FullName }
    }

    foreach ($extra in @('OptGuideOnDeviceModel', 'optimization_guide_model_store')) {
        $path = Join-Path $Root $extra
        if ((Test-Path -LiteralPath $path) -and ($targets -notcontains $path)) { $targets += $path }
    }

    return $targets
}

$script:results = @()
$policy = Import-DiskPolicy -Path $PolicyPath
$auditDrives = Resolve-AuditDrives -ConfiguredDrives $policy.full_audit_drives
$beforeDrives = @($auditDrives | ForEach-Object { Get-DriveState -Letter $_ })

foreach ($path in @($ProjectWorkPath)) {
    if ([string]::IsNullOrWhiteSpace($path)) { continue }
    if (Test-SafeProjectWorkPath -Path $path) {
        Remove-WholePathSafe -Name 'codex-project-work' -Path $path
    } else {
        Add-Result -Name 'codex-project-work' -Path $path -Status 'failed' -BeforeBytes $null -AfterBytes $null -Reason 'path-not-recognized-as-safe-codex-project-work'
    }
}

if ($IncludeConfirmedCaches) {
    Clear-DirectoryContentsSafe -Name 'windows-temp' -Path "$env:SystemRoot\Temp"
    Clear-DirectoryContentsSafe -Name 'user-temp' -Path (Join-Path $userProfile 'AppData\Local\Temp')
    Clear-DirectoryContentsSafe -Name 'uv-cache' -Path (Join-Path $userProfile 'AppData\Local\uv\cache')
    Clear-DirectoryContentsSafe -Name 'whisper-cache' -Path (Join-Path $userProfile '.cache\whisper')
    Clear-DirectoryContentsSafe -Name 'gemini-antigravity-backup' -Path (Join-Path $userProfile '.gemini\antigravity-backup')
}

if ($IncludeBrowserCaches) {
    $browserRoots = @(
        (Join-Path $userProfile 'AppData\Local\Google\Chrome\User Data'),
        (Join-Path $userProfile 'AppData\Local\Microsoft\Edge\User Data')
    )
    foreach ($root in $browserRoots) {
        foreach ($target in (Get-BrowserCacheTargets -Root $root)) {
            Clear-DirectoryContentsSafe -Name 'browser-pure-cache' -Path $target
        }
    }
}

$afterDrives = @($auditDrives | ForEach-Object { Get-DriveState -Letter $_ })
$driveDelta = foreach ($before in $beforeDrives) {
    $after = $afterDrives | Where-Object { $_.drive -eq $before.drive } | Select-Object -First 1
    [pscustomobject]@{
        drive          = $before.drive
        before_free_gb = $before.free_gb
        after_free_gb  = if ($after) { $after.free_gb } else { $null }
        delta_gb       = if ($after) { [math]::Round(($after.free_gb - $before.free_gb), 2) } else { $null }
    }
}

$report = [pscustomobject]@{
    mode               = if ($Execute) { 'confirmed-clean' } else { 'confirmed-plan' }
    generated_at       = Get-Date
    execute            = [bool]$Execute
    include_confirmed  = [bool]$IncludeConfirmedCaches
    include_browser    = [bool]$IncludeBrowserCaches
    before_drives      = $beforeDrives
    after_drives       = $afterDrives
    drive_delta        = @($driveDelta)
    cleaned            = @($results | Where-Object { $_.status -in @('deleted', 'cleared', 'partial') -and $_.freed_gb -gt 0 })
    skipped_in_use     = @($results | Where-Object { $_.status -in @('skipped-in-use', 'partial') -and $_.reason })
    failed             = @($results | Where-Object { $_.status -eq 'failed' })
    missing            = @($results | Where-Object { $_.status -eq 'missing' })
    all_results        = @($results)
}

if ($EmitJson) {
    $report | ConvertTo-Json -Depth 8
} else {
    $report
}
