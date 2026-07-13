Set-StrictMode -Version Latest

function Expand-PolicyEnvironmentVariables {
    param([Parameter(Mandatory)][object]$Value)

    if ($Value -is [string]) {
        return [Environment]::ExpandEnvironmentVariables($Value)
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) { $result[$key] = Expand-PolicyEnvironmentVariables $Value[$key] }
        return [pscustomobject]$result
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return @($Value | ForEach-Object { Expand-PolicyEnvironmentVariables $_ })
    }
    if ($Value -is [pscustomobject]) {
        $result = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) { $result[$property.Name] = Expand-PolicyEnvironmentVariables $property.Value }
        return [pscustomobject]$result
    }
    return $Value
}

function Resolve-AuditDrives {
    param([object[]]$ConfiguredDrives)

    $configured = @($ConfiguredDrives)
    if ($configured -notcontains 'AUTO_FIXED_DRIVES') {
        return @($configured | ForEach-Object { ($_ -replace '[:\\]', '').Substring(0,1).ToUpperInvariant() } | Select-Object -Unique)
    }

    $letters = @()
    try { $letters = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop | Where-Object { $_.DeviceID } | ForEach-Object { $_.DeviceID.Substring(0,1) }) } catch { }
    if (-not $letters) {
        $letters = @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | ForEach-Object { $_.Name.Substring(0,1) })
    }
    if (-not $letters -and $env:SystemDrive) { $letters = @($env:SystemDrive.Substring(0,1)) }
    $system = if ($env:SystemDrive) { $env:SystemDrive.Substring(0,1).ToUpperInvariant() } else { 'C' }
    return @($letters | ForEach-Object { $_.ToUpperInvariant() } | Sort-Object { if ($_ -eq $system) { 0 } else { 1 } }, { $_ } -Unique)
}

function Resolve-ClosingReportDirectory {
    param([string]$ConfiguredPath)
    $path = [Environment]::ExpandEnvironmentVariables($ConfiguredPath)
    if ([string]::IsNullOrWhiteSpace($path)) { throw 'Closing report directory is empty.' }
    return [IO.Path]::GetFullPath($path)
}

function Import-DiskPolicy {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Policy file not found: $Path" }
    return Expand-PolicyEnvironmentVariables (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}
