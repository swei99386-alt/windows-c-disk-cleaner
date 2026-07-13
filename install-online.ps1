[CmdletBinding()]
param(
    [string]$Ref = 'main',
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'windows-c-disk-cleaner'),
    [ValidateSet('All', 'ClaudeCode', 'Codex', 'Antigravity')][string[]]$Target = @('All'),
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
$temp = Join-Path ([IO.Path]::GetTempPath()) "windows-c-disk-cleaner-$([guid]::NewGuid().ToString('N'))"
$zip = Join-Path $temp 'source.zip'
try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $url = "https://github.com/swei99386-alt/windows-c-disk-cleaner/archive/refs/heads/$Ref.zip"
    Write-Host "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $zip) -or (Get-Item $zip).Length -lt 1KB) { throw 'Downloaded archive is empty or incomplete.' }
    $extract = Join-Path $temp 'extract'
    Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
    $source = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
    if (-not $source -or -not (Test-Path (Join-Path $source.FullName 'install.ps1'))) { throw 'Archive extraction succeeded but install.ps1 was not found.' }
    if (Test-Path -LiteralPath $InstallRoot) {
        if (-not $Force) { throw "Install root already exists: $InstallRoot. Use -Force to update." }
        Rename-Item -LiteralPath $InstallRoot -NewName "$([IO.Path]::GetFileName($InstallRoot)).backup-$((Get-Date).ToString('yyyyMMdd-HHmmss'))" -ErrorAction Stop
    }
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    Get-ChildItem -LiteralPath $source.FullName -Force | Copy-Item -Destination $InstallRoot -Recurse -Force
    & (Join-Path $InstallRoot 'install.ps1') -Target $Target -Force
    if ($LASTEXITCODE -ne 0) { throw "Local installer failed with exit code: $LASTEXITCODE" }
} catch {
    Write-Error "Online installation failed: $($_.Exception.Message)"
    exit 1
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
