[简体中文](./README.md) | English

# Windows C Disk Cleaner

An AI-assisted Windows disk auditing and cleanup skill. It does not turn every uncertainty into a user decision: it recommends delete, keep, or move actions using a recovery-cost-first rule, while still requiring confirmation of the exact deletion manifest.

## Safety warning

It recommends deletion for public installers that can be re-downloaded, incomplete downloads, and SHA-256-verified duplicate copies. It does not hand-delete unique personal data, live runtimes, WSL/Docker virtual disks, system directories, or installed applications. Every deletion requires an exact-path manifest and user confirmation; permanent deletion is not presented as recoverable.

## Core capabilities

- Detects available fixed disks and prioritizes the Windows system drive
- Uses recovery cost instead of blanket conservatism to judge large files, caches, and backups
- Cleans low-risk caches only after confirmation
- Recommends deletion of public installers; keeps one SHA-256-verified duplicate copy
- Verifies repair backups and migration copies against active desktop/project paths
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
Check Downloads: recommend deleting public installers, but only delete personal data after proving it is duplicated.
Check whether this App.pre-repair folder is a disposable repair backup; recommend deletion when the active app is healthy.
```

## Example output

See [docs/example-output.md](./docs/example-output.md). It is a format example and does not represent a fixed cleanup result.

## Safety levels

The public documentation uses six categories: default-delete, dedupe-keep-one, verified-backup-delete, move-or-archive, official-or-app-only, and never-touch.

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
