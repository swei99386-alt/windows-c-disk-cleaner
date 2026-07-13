[CmdletBinding()]
param(
    [string[]]$Drives,
    [string]$OutputDir,
    [decimal]$MinTopLevelGB = 0.5,
    [switch]$DeepRootScan,
    [switch]$NoWrite,
    [switch]$EmitJson
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib\PolicyHelpers.ps1')
$policy = Import-DiskPolicy -Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'config\auto-clean-policy.json')
if (-not $Drives) { $Drives = Resolve-AuditDrives -ConfiguredDrives $policy.full_audit_drives }
if (-not $OutputDir) { $OutputDir = Resolve-ClosingReportDirectory -ConfiguredPath $policy.closing_report_dir }

function Convert-ToGB {
    param([Nullable[double]]$Bytes)
    if ($null -eq $Bytes) { return $null }
    return [math]::Round(($Bytes / 1GB), 2)
}

function Get-NormalizedDriveName {
    param([string]$Drive)
    $name = ($Drive -replace '[:\\]', '').Trim()
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }
    return $name.Substring(0, 1).ToUpperInvariant()
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

function Get-PathFact {
    param(
        [string]$Path,
        [string]$ActionClass,
        [string]$WhatItIs,
        [string]$DeleteImpact,
        [string]$MoveImpact,
        [string]$OwnerHint
    )

    $exists = Test-Path -LiteralPath $Path
    $item = if ($exists) { Get-Item -LiteralPath $Path -Force } else { $null }
    $sizeBytes = if ($exists) { Get-ItemSizeBytes -Path $Path } else { $null }

    [pscustomobject]@{
        path             = $Path
        exists           = [bool]$exists
        size_gb          = Convert-ToGB $sizeBytes
        action_class     = $ActionClass
        what_it_is       = $WhatItIs
        delete_impact    = $DeleteImpact
        move_impact      = $MoveImpact
        owner_hint       = $OwnerHint
        created_time     = if ($item) { $item.CreationTime } else { $null }
        last_write_time  = if ($item) { $item.LastWriteTime } else { $null }
        last_access_time = if ($item) { $item.LastAccessTime } else { $null }
    }
}

function Get-DriveSummary {
    param([string]$Drive)

    $driveName = Get-NormalizedDriveName -Drive $Drive
    if (-not $driveName) { return $null }

    $psDrive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
    if (-not $psDrive) { return $null }

    [pscustomobject]@{
        drive    = "$driveName`:"
        root     = "$driveName`:\"
        total_gb = Convert-ToGB ([double]($psDrive.Used + $psDrive.Free))
        used_gb  = Convert-ToGB ([double]$psDrive.Used)
        free_gb  = Convert-ToGB ([double]$psDrive.Free)
    }
}

function Get-TopLevelRows {
    param(
        [string]$Drive,
        [decimal]$MinimumGB
    )

    $driveName = Get-NormalizedDriveName -Drive $Drive
    if (-not $driveName) { return @() }

    $root = "$driveName`:\"
    if (-not (Test-Path -LiteralPath $root)) { return @() }

    $rows = foreach ($item in Get-ChildItem -LiteralPath $root -Force) {
        $sizeBytes = if ($item.PSIsContainer) {
            Get-ItemSizeBytes -Path $item.FullName
        } else {
            [double]$item.Length
        }
        $sizeGB = Convert-ToGB $sizeBytes
        if ($null -eq $sizeGB -or $sizeGB -lt $MinimumGB) { continue }

        [pscustomobject]@{
            drive            = "$driveName`:"
            path             = $item.FullName
            type             = if ($item.PSIsContainer) { 'directory' } else { 'file' }
            size_gb          = $sizeGB
            last_write_time  = $item.LastWriteTime
            last_access_time = $item.LastAccessTime
        }
    }

    @($rows | Sort-Object size_gb -Descending)
}

function Get-DockerObservation {
    $service = Get-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue
    $processes = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match 'docker|com\.docker'
    } | Select-Object ProcessName, Id, Path)

    $dockerVhdx = @(Get-ChildItem -LiteralPath "$env:LOCALAPPDATA\Docker" -Filter '*.vhdx' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName)

    $vhdx = Get-PathFact `
        -Path $dockerVhdx `
        -ActionClass 'watch_for_two_weeks' `
        -WhatItIs 'Docker Desktop 的 WSL 虚拟磁盘' `
        -DeleteImpact '不要直接删除，否则 Docker 镜像、容器、数据卷可能损坏或消失。' `
        -MoveImpact '只能通过 Docker/WSL 支持的迁移方式处理，或者官方卸载清理后再处理残留。' `
        -OwnerHint 'Docker Desktop'

    [pscustomobject]@{
        service_name   = if ($service) { $service.Name } else { $null }
        service_status = if ($service) { $service.Status.ToString() } else { 'not-found' }
        processes      = $processes
        data_vhdx      = $vhdx
    }
}

function Get-WslObservation {
    $wslList = $null
    try {
        $wslList = wsl.exe -l -v 2>$null
    } catch {
        $wslList = $null
    }

    $wslVhdx = @(Get-ChildItem -LiteralPath "$env:LOCALAPPDATA\Packages" -Filter 'ext4.vhdx' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName)

    $mainVhdx = Get-PathFact `
        -Path $wslVhdx `
        -ActionClass 'watch_or_export' `
        -WhatItIs 'WSL Ubuntu 虚拟磁盘，可能用于本地 Linux 开发环境' `
        -DeleteImpact '不要直接删除，否则这个 Linux 环境里的应用和文件可能丢失。' `
        -MoveImpact '如果要移动或退役，安全路线是导出、注销、再导入或备份。' `
        -OwnerHint 'WSL'

    [pscustomobject]@{
        wsl_list_output = $wslList
        main_vhdx       = $mainVhdx
    }
}

$userProfile = [Environment]::GetFolderPath('UserProfile')
$knownPaths = @(
    @{ Path = "$userProfile\AppData\Roaming\Claude"; Action = 'never_touch_direct'; What = 'Claude Desktop 的应用数据和本地状态'; Delete = '不要整目录删除，可能丢登录状态、本地状态、历史记录或应用数据。只能在摸清后清明确的缓存子目录。'; Move = '不作为第一优先搬迁对象。真要搬，必须先关闭应用并准备回滚方案。'; Owner = 'Claude Desktop' },
    @{ Path = "$userProfile\AppData\Local\Google\Chrome\User Data"; Action = 'app_managed_or_cache_subdirs'; What = 'Chrome 用户配置、登录状态、书签以及缓存混在一起'; Delete = '不要删整个目录。只允许清 Cache、Code Cache、GPUCache 等纯缓存子目录。'; Move = '不建议直接搬，除非做 Chrome 配置迁移。'; Owner = 'Chrome' },
    @{ Path = "$userProfile\AppData\Roaming\Tencent"; Action = 'app_managed_or_move'; What = '腾讯/微信/QQ 的聊天、图片、文件和应用数据'; Delete = '可能删除聊天记录、图片和文件。优先用微信/QQ 自带存储管理，或先迁移归档。'; Move = '部分文件归档可以搬，但要先确认微信当前数据路径。'; Owner = '微信/Tencent' },
    @{ Path = "$userProfile\AppData\Local\Kingsoft"; Action = 'app_managed'; What = 'WPS/金山办公的本地数据和缓存'; Delete = '手删可能丢最近打开记录、离线缓存或登录状态。'; Move = '优先用 WPS 设置或官方清理，不建议直接搬目录。'; Owner = 'WPS/金山' },
    @{ Path = "$userProfile\AppData\Local\pnpm"; Action = 'cache_or_store'; What = 'pnpm 的包仓库/缓存，里面是前端项目依赖的公共副本'; Delete = '应优先用 pnpm store prune 清理。删多了以后某些项目第一次运行会重新下载依赖。'; Move = '如果以后持续变大，可以配置 pnpm store 到别的盘。'; Owner = 'pnpm' },
    @{ Path = "$userProfile\AppData\Roaming\npm"; Action = 'app_managed'; What = 'npm 全局命令行工具安装目录'; Delete = '不要删整个目录，否则一些全局命令可能直接消失。'; Move = '可以改 npm prefix，但可能影响 PATH，需单独处理。'; Owner = 'npm 全局工具' },
    @{ Path = "$userProfile\AppData\Local\ms-playwright"; Action = 'cache_rebuildable'; What = 'Playwright 下载的浏览器内核'; Delete = '如果近期不用浏览器自动化，可以删；下次运行 playwright install 会重新下载。'; Move = '以后如果反复变大，可用 PLAYWRIGHT_BROWSERS_PATH 改到别的盘。'; Owner = 'Playwright' },
    @{ Path = "$userProfile\AppData\Local\Camoufox"; Action = 'cache_rebuildable'; What = 'Camoufox 指纹浏览器/自动化运行环境'; Delete = '下次自动化可能要重新下载或初始化。'; Move = '只有工具支持自定义路径时才建议搬。'; Owner = 'Camoufox' },
    @{ Path = "$userProfile\.vscode"; Action = 'review_extensions'; What = 'VS Code 扩展、设置和用户状态'; Delete = '盲删会把扩展和设置一起删掉。应该卸载不用的扩展。'; Move = '除非专门配置 VS Code 扩展目录，否则不建议搬。'; Owner = 'VS Code' }
)

$driveSummaries = @($Drives | ForEach-Object { Get-DriveSummary -Drive $_ } | Where-Object { $null -ne $_ })
$knownItems = @(
    foreach ($spec in $knownPaths) {
        Get-PathFact -Path $spec.Path -ActionClass $spec.Action -WhatItIs $spec.What -DeleteImpact $spec.Delete -MoveImpact $spec.Move -OwnerHint $spec.Owner
    }
) | Sort-Object @{ Expression = 'size_gb'; Descending = $true }, path

$topLevelItems = @()
if ($DeepRootScan) {
    $topLevelItems = @(
        foreach ($drive in $Drives) {
            Get-TopLevelRows -Drive $drive -MinimumGB $MinTopLevelGB
        }
    )
}

$dockerObservation = Get-DockerObservation
$wslObservation = Get-WslObservation

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$report = [pscustomobject]@{
    generated_at       = Get-Date
    language           = 'zh-CN'
    output_dir         = $OutputDir
    deep_root_scan     = [bool]$DeepRootScan
    min_top_level_gb   = $MinTopLevelGB
    drive_summaries    = $driveSummaries
    known_large_items  = $knownItems
    top_level_items    = $topLevelItems
    docker_observation = $dockerObservation
    wsl_observation    = $wslObservation
    next_rules         = @(
        '尽量让 C: 保持 50GB 以上可用空间。',
        '不要手工删除 Docker 或 WSL 的虚拟磁盘。',
        'Claude、微信、WPS 和个人文档都按"应用管理/用户数据"处理，不要整目录硬删。',
        '缓存可以删，但要先说明哪些工具之后可能会重新下载或重建。'
    )
}

if (-not $NoWrite) {
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $jsonPath = Join-Path $OutputDir "disk-governor-snapshot-$timestamp.json"
    $csvPath = Join-Path $OutputDir "disk-governor-known-items-$timestamp.csv"
    $mdPath = Join-Path $OutputDir "disk-governor-snapshot-$timestamp.md"

    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    $knownItems | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    $md = @()
    $md += '# Windows 磁盘值班快照'
    $md += ''
    $md += "- 生成时间：$($report.generated_at)"
    $md += "- 是否深度扫描一级目录：$($report.deep_root_scan)"
    $md += ''
    $md += '## 磁盘概览'
    $md += ''
    $md += '| 盘符 | 总容量 GB | 已用 GB | 可用 GB |'
    $md += '|---|---:|---:|---:|'
    foreach ($row in $driveSummaries) {
        $md += "| $($row.drive) | $($row.total_gb) | $($row.used_gb) | $($row.free_gb) |"
    }
    $md += ''
    $md += '## 已知大项'
    $md += ''
    $md += '| 路径 | 大小 GB | 处理分类 | 这是什么 | 删除影响 |'
    $md += '|---|---:|---|---|---|'
    foreach ($row in ($knownItems | Where-Object { $_.exists -and $_.size_gb -ge 0.1 } | Select-Object -First 40)) {
        $safePath = $row.path -replace '\|', '/'
        $safeWhat = $row.what_it_is -replace '\|', '/'
        $safeImpact = $row.delete_impact -replace '\|', '/'
        $md += "| $safePath | $($row.size_gb) | $($row.action_class) | $safeWhat | $safeImpact |"
    }
    if ($DeepRootScan) {
        $md += ''
        $md += '## 各盘一级大目录'
        $md += ''
        $md += '| 盘符 | 路径 | 大小 GB | 类型 |'
        $md += '|---|---|---:|---|'
        foreach ($row in ($topLevelItems | Sort-Object size_gb -Descending | Select-Object -First 80)) {
            $safePath = $row.path -replace '\|', '/'
            $md += "| $($row.drive) | $safePath | $($row.size_gb) | $($row.type) |"
        }
    }
    $md += ''
    $md += '## 观察项'
    $md += ''
    $md += "- Docker 服务状态：$($dockerObservation.service_status)"
    $md += "- Docker 数据虚拟盘：$($dockerObservation.data_vhdx.size_gb) GB，最后写入：$($dockerObservation.data_vhdx.last_write_time)"
    $md += "- WSL 主虚拟盘：$($wslObservation.main_vhdx.size_gb) GB，最后写入：$($wslObservation.main_vhdx.last_write_time)"
    $md += ''
    $md += '## 下一轮规则'
    foreach ($rule in $report.next_rules) {
        $md += "- $rule"
    }

    $md | Set-Content -LiteralPath $mdPath -Encoding UTF8

    $report | Add-Member -NotePropertyName written_files -NotePropertyValue ([pscustomobject]@{
        json = $jsonPath
        csv  = $csvPath
        md   = $mdPath
    })
}

if ($EmitJson) {
    $report | ConvertTo-Json -Depth 8
} else {
    $report
}
