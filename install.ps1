# Windows C Drive Cleaner - Auto Installer & Configurator
# This script automatically updates the username in your policy config and links the skill to your AI assistants.

$username = $env:USERNAME
Write-Host "Detected Windows Username: $username" -ForegroundColor Cyan

# 1. Update config/auto-clean-policy.json
$configPath = Join-Path $PSScriptRoot "config\auto-clean-policy.json"
if (Test-Path $configPath) {
    Write-Host "Updating auto-clean-policy.json with real username..." -ForegroundColor Yellow
    $content = Get-Content $configPath -Raw
    # Replace YOURUSERNAME
    $newContent = $content -replace "YOURUSERNAME", $username
    # Save back
    Set-Content $configPath -Value $newContent -Encoding UTF8
    Write-Host "Config file updated successfully." -ForegroundColor Green
} else {
    Write-Warning "config/auto-clean-policy.json not found!"
}

# 2. Try to link to AI assistants
$skillsMap = @{
    "Claude Code" = Join-Path $env:USERPROFILE ".claude\skills"
    "Codex"       = Join-Path $env:USERPROFILE ".codex\skills"
    "Antigravity" = Join-Path $env:USERPROFILE ".gemini\config\skills"
}

$currentDir = $PSScriptRoot
$folderName = "windows-c-disk-cleaner"

foreach ($assistant in $skillsMap.Keys) {
    $targetSkillsDir = $skillsMap[$assistant]
    if (Test-Path $targetSkillsDir) {
        $linkPath = Join-Path $targetSkillsDir $folderName
        Write-Host "Installing to ${assistant}..." -ForegroundColor Yellow
        if (Test-Path $linkPath) {
            Write-Host "Link already exists at ${linkPath}, removing it to recreate..." -ForegroundColor DarkYellow
            try {
                # Attempt to delete. Force handles read-only files, Recurse handles directories.
                Remove-Item $linkPath -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Warning "Could not remove existing path ${linkPath}: $_"
            }
        }
        
        # Create symbolic link. Note: New-Item -ItemType SymbolicLink may require developer mode or admin rights.
        try {
            New-Item -ItemType SymbolicLink -Path $linkPath -Target $currentDir -ErrorAction Stop | Out-Null
            Write-Host "Successfully linked to ${assistant}!" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to create symbolic link (requires Developer Mode or Administrator privileges). Copying files instead..."
            try {
                Copy-Item -Path $currentDir -Destination $linkPath -Recurse -Force -ErrorAction Stop
                Write-Host "Successfully copied to ${assistant}!" -ForegroundColor Green
            } catch {
                Write-Error "Failed to install to ${assistant}: $_"
            }
        }
    } else {
        # Check if the parent directory exists, if so, we can optionally create the skills folder.
        # e.g., if .claude exists but .claude/skills does not, create it.
        $parentDir = Split-Path $targetSkillsDir
        if (Test-Path $parentDir) {
            Write-Host "Creating skills directory for ${assistant} at ${targetSkillsDir}..." -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $targetSkillsDir -Force | Out-Null
            # Retry link
            $linkPath = Join-Path $targetSkillsDir $folderName
            try {
                New-Item -ItemType SymbolicLink -Path $linkPath -Target $currentDir -ErrorAction Stop | Out-Null
                Write-Host "Successfully linked to ${assistant}!" -ForegroundColor Green
            } catch {
                Copy-Item -Path $currentDir -Destination $linkPath -Recurse -Force
                Write-Host "Successfully copied to ${assistant}!" -ForegroundColor Green
            }
        }
    }
}

Write-Host "`nInstallation Completed successfully!" -ForegroundColor Green
Write-Host "You can now tell your AI assistant: '帮我扫一下 C 盘哪里占地方最多'" -ForegroundColor Cyan
