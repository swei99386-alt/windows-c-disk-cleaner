[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failed = @()
$required = @('README.md','README_EN.md','SKILL.md','LICENSE','SECURITY.md','CONTRIBUTING.md','CHANGELOG.md','install.ps1','install-online.ps1','config/auto-clean-policy.json','agents/openai.yaml')
foreach ($path in $required) { if (-not (Test-Path (Join-Path $root $path))) { $failed += "Missing file: $path" } }
foreach ($file in Get-ChildItem $root -Recurse -Filter '*.ps1' -File) {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count) { $failed += "PowerShell syntax error: $($file.FullName)" }
}
foreach ($file in Get-ChildItem $root -Recurse -Filter '*.json' -File) { try { Get-Content $file.FullName -Raw | ConvertFrom-Json | Out-Null } catch { $failed += "JSON error: $($file.FullName)" } }
$skill = Get-Content (Join-Path $root 'SKILL.md') -Raw
$agent = Get-Content (Join-Path $root 'agents/openai.yaml') -Raw
if (-not ($skill -split "`r?`n" | Where-Object { $_ -eq 'name: windows-c-disk-cleaner' })) { $failed += 'Skill identifier mismatch' }
$agentNeedle = [char]36 + 'windows-c-disk-cleaner'
if (-not $agent.Contains($agentNeedle)) { $failed += 'Agent identifier mismatch' }
$scanFiles = Get-ChildItem $root -Recurse -File | Where-Object { $_.FullName -notmatch '\.git' -and $_.Extension -in @('.ps1','.json','.yaml','.yml') }
$forbidden = @('YOUR' + 'USERNAME','E:\' + 'disk-audit-reports','E:\' + 'Docker_Data','E:\' + 'WSL\Ubuntu',([char]36) + 'windows-' + 'disk-governor')
foreach ($file in $scanFiles) { foreach ($pattern in $forbidden) { if (Select-String -LiteralPath $file.FullName -Pattern ([regex]::Escape($pattern)) -Quiet) { $failed += "Forbidden residue: $($file.FullName)"; break } } }
$temp = Join-Path $env:TEMP ('windows-c-disk-cleaner-test-' + [guid]::NewGuid().ToString('N'))
$old = $env:USERPROFILE; $env:USERPROFILE = $temp
try {
    . (Join-Path $root 'scripts/lib/PolicyHelpers.ps1')
    $expanded = Expand-PolicyEnvironmentVariables '%USERPROFILE%\Documents'
    if ($expanded -ne (Join-Path $temp 'Documents')) { $failed += 'Environment expansion failed' }
    $plan = & (Join-Path $root 'install.ps1') -Target Codex -WhatIf 2>&1 | Out-String
    if (-not $plan -or (Test-Path (Join-Path $temp '.codex'))) { $failed += 'Installer WhatIf failed' }
    $blocked = & pwsh -NoProfile -File (Join-Path $root 'scripts/run_disk_governor.ps1') -Mode safe-clean 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -or $blocked -notmatch 'requires -Execute') { $failed += 'Execution gate failed' }
    $directBlocked = & pwsh -NoProfile -File (Join-Path $root 'scripts/cleanup_low_risk.ps1') -Execute 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -or $directBlocked -notmatch 'requires both -Execute and -ConfirmCleanup') { $failed += 'Direct cleanup gate failed' }
    $treeBlocked = & pwsh -NoProfile -File (Join-Path $root 'scripts/run_from_treesize.ps1') -Execute 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -or $treeBlocked -notmatch 'requires both -Execute and -ConfirmCleanup') { $failed += 'Tree runner gate failed' }
} finally { $env:USERPROFILE = $old; if (Test-Path $temp) { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue } }
if ($failed.Count) { $failed | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Output 'PASS: repository validation'
