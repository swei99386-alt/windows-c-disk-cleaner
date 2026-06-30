[CmdletBinding()]
param(
    [string]$TargetPath = 'C:\'
)

$ErrorActionPreference = 'Stop'

$candidates = @(
    'C:\Program Files\JAM Software\TreeSize Free\TreeSizeFree.exe',
    'C:\Program Files (x86)\JAM Software\TreeSize Free\TreeSizeFree.exe',
    "$env:LOCALAPPDATA\Programs\JAM Software\TreeSize Free\TreeSizeFree.exe"
)

$exe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $exe) {
    $command = Get-Command '*TreeSize*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        $exe = $command.Source
    }
}

if (-not $exe) {
    throw 'TreeSize executable not found on this machine.'
}

Start-Process -FilePath $exe -ArgumentList $TargetPath

[pscustomobject]@{
    started     = $true
    executable  = $exe
    target_path = $TargetPath
    note        = 'TreeSize launched. Scan C:, then send screenshots or export a report file.'
}
