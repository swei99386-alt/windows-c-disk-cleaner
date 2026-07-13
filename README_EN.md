[简体中文](./README.md) | English

# Windows C Disk Cleaner

An AI-assisted Windows disk auditing and conservative cleanup skill. It reports by default and only cleans strictly whitelisted low-risk caches after explicit user confirmation.

## Safety warning

Review the report before acting. The tool does not automatically delete personal documents, Downloads, Desktop files, WSL data, Docker virtual disks, or system directories. Cleanup requires an explicit `-Execute` switch. Migration and directory links are always separate manual tasks, not automated Skill behavior.

## Core capabilities

- Detects available fixed disks and prioritizes the Windows system drive
- Explains large files, developer caches, browser caches, and VHDX risks
- Cleans low-risk caches only after confirmation
- Reports duplicate installers and large files
- Emits JSON reports reusable by Claude Code, Codex, and other agents

## Quick installation

Clone and inspect the code first:

```powershell
git clone https://github.com/swei99386-alt/windows-c-disk-cleaner.git
cd windows-c-disk-cleaner
powershell -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Online installation downloads and verifies a ZIP; it does not use opaque `irm | iex`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest 'https://raw.githubusercontent.com/swei99386-alt/windows-c-disk-cleaner/main/install-online.ps1' -OutFile '$env:TEMP\windows-c-disk-cleaner-install.ps1'; & '$env:TEMP\windows-c-disk-cleaner-install.ps1'"
```

The installer supports `-Target All|ClaudeCode|Codex|Antigravity`, `-InstallMode Auto|Junction|Copy`, `-Force`, and `-WhatIf`. Conflicts are preserved and reported; `-Force` backs them up before updating.

## Supported AI assistants

Claude Code, Codex, and Antigravity. The installer reports `installed`, `already_installed`, `conflict`, and `failed` per target.

## Usage examples

```text
Audit why my C drive is nearly full; report only and do not delete anything.
Scan all fixed disks and list directories larger than 1 GB.
Clean only strictly whitelisted low-risk caches, but show the estimated reclaim first.
Check Downloads for duplicate installers, but never delete personal documents automatically.
```

## Example output

See [docs/example-output.md](./docs/example-output.md). It is a format example and does not represent a fixed cleanup result.

## Safety levels

The public documentation uses five categories: safe to clean, clean after user confirmation, move or archive, handle through Windows or the app, and do not handle manually.

## Manual commands

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_disk_governor.ps1 -Mode report-only -EmitJson
powershell -ExecutionPolicy Bypass -File .\scripts\find_duplicate_downloads.ps1 -EmitJson
pwsh -NoProfile -File .\scripts\run_disk_governor.ps1 -Mode safe-clean -Execute
```

## Verification status

- CI verified: Windows GitHub Actions PowerShell 7 parsing, JSON, repository rules, and installer WhatIf.
- Manually verified: repository tests and installer WhatIf were run in the current Windows environment.
- Not yet verified: real installation in each Claude Code, Codex, and Antigravity client.

This project is currently verified with PowerShell 7; Windows PowerShell 5.1 is not a supported target.

## Current limitations

No real cleanup was run, so no space reclaimed is claimed; real screenshots are pending manual addition. Docker, WSL, and application migration are discovery/report-only and cannot be auto-deleted or auto-migrated. Browser profile trees are not scanned while the browser is running.

## File structure

`SKILL.md`, `config/auto-clean-policy.json`, `scripts/`, `references/`, `agents/openai.yaml`, `tests/`, and `.github/workflows/ci.yml`.

## Contributing

Read [CONTRIBUTING.md](./CONTRIBUTING.md). Do not expand dangerous automatic deletion or submit private paths.

## License

MIT
