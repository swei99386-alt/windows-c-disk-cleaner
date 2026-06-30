[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReportPath,
    [int]$Top = 30,
    [double]$MinSizeGB = 1,
    [switch]$EmitJson
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ReportPath)) {
    throw "TreeSize report not found: $ReportPath"
}

function Convert-SizeTextToGB {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $value = $Text.Trim()
    if ($value -match '([0-9]+(?:\.[0-9]+)?)\s*(TB|GB|MB|KB|B)') {
        $number = [double]$matches[1]
        switch ($matches[2]) {
            'TB' { return [math]::Round($number * 1024, 2) }
            'GB' { return [math]::Round($number, 2) }
            'MB' { return [math]::Round($number / 1024, 2) }
            'KB' { return [math]::Round($number / 1MB, 4) }
            default { return 0 }
        }
    }
    return $null
}

$extension = [IO.Path]::GetExtension($ReportPath).ToLowerInvariant()
$summary = @()

if ($extension -eq '.csv') {
    $rows = Import-Csv -LiteralPath $ReportPath
    foreach ($row in $rows | Select-Object -First $Top) {
        $pathValue = $row.Path
        if (-not $pathValue) { $pathValue = $row.Name }
        $sizeText = $row.Size
        if (-not $sizeText) { $sizeText = $row.'Allocated' }
        $sizeGB = Convert-SizeTextToGB $sizeText
        $summary += [pscustomobject]@{
            path    = $pathValue
            size_gb = $sizeGB
            is_path = [bool]($pathValue -match '^[A-Za-z]:\\')
            raw     = $row
        }
    }
} else {
    $lines = Get-Content -LiteralPath $ReportPath | Select-Object -First $Top
    foreach ($line in $lines) {
        $sizeGB = Convert-SizeTextToGB $line
        $pathMatch = [regex]::Match($line, '[A-Za-z]:\\[^,;]+')
        $summary += [pscustomobject]@{
            path    = if ($pathMatch.Success) { $pathMatch.Value.Trim() } else { $line }
            size_gb = $sizeGB
            is_path = $pathMatch.Success
            raw     = $line
        }
    }
}

$heatPaths = @(
    $summary |
        Where-Object { $_.is_path -and $null -ne $_.size_gb -and $_.size_gb -ge $MinSizeGB } |
        Select-Object -ExpandProperty path -Unique
)

$result = [pscustomobject]@{
    report_path = $ReportPath
    input_type  = if ($extension -eq '.csv') { 'csv' } else { 'text' }
    item_count  = $summary.Count
    items       = $summary
    heat_paths  = $heatPaths
}

if ($EmitJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    $result
}
