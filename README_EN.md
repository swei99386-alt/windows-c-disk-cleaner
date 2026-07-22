[简体中文](./README.md) | English

# Windows C Disk Cleaner

Is C: or E: full, but deleting files blindly feels dangerous? This skill makes an AI agent inspect the evidence first, then tell you clearly: **delete, keep, or move.**

Its rule is simple:

> If the real cost of getting a file back is low, it does not deserve to occupy scarce disk space forever.

Public installers, incomplete downloads, and proven duplicate files receive a clear delete recommendation. Unique data and live runtimes are protected.

## What you get

- An exact deletion manifest: path, size, why it is safe to recover, and deletion impact.
- Public installers are treated as re-downloadable, not as fake “high-risk” files.
- SHA-256 proves exact duplicates before all but one copy are removed.
- Repair backups are deleted only after the live version is verified healthy; active runtimes are protected.
- Before/after C: and E: free-space reporting.

## Who it is for

**Ordinary Windows users:** paste one prompt into Claude Code, Codex, or another AI agent that can access your local files.

**AI-tool users:** install this skill so an agent follows the same rules when asked about a full C: drive, duplicate installers, or a suspiciously large file.

## Start in three steps

1. Ask for an audit only.
2. Review the exact deletion manifest.
3. Confirm the exact paths and receive a before/after space report.

Copy this prompt:

```text
Audit C: and E: using this rule: delete when recovery cost is lower than the cost of keeping the file. Do not delete anything yet. Produce an exact deletion manifest with path, size, reason, and deletion impact.
```

See the full [prompt library](./docs/copyable-prompts.md).

## A real, anonymized case

In one verified cleanup, the skill reclaimed **12.49 GB** by removing public installers and SHA-256-proven duplicate copies. It did not target WSL, Docker, Claude runtime data, unique files, or the active Windows Desktop. [Read the case and rule changes](./docs/real-cleanup-case.md).

This is an example of the decision process, not a promised result for every machine.

## Install for agents

Install with Skills CLI for Codex and Claude Code:

```powershell
npx skills add swei99386-alt/windows-c-disk-cleaner -g -a codex -a claude-code
```

List the public repository skill first:

```powershell
npx skills add swei99386-alt/windows-c-disk-cleaner --list
```

Or clone, inspect, and install:

```powershell
git clone https://github.com/swei99386-alt/windows-c-disk-cleaner.git
cd windows-c-disk-cleaner
powershell -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## What it will not do

- It does not make users decide about ordinary public installers merely because the agent is uncertain.
- It does not hand-delete System32, Windows core files, WSL/Docker virtual disks, installed applications, or messaging-app data.
- It does not assume a migrated folder named “Desktop” is the active Windows Desktop; it verifies the live known-folder path first.
- It does not delete content from personal folders without an exact manifest and current-thread confirmation.

## Agent decision rules

| Situation | Default recommendation |
|---|---|
| Re-downloadable EXE/MSI/APK or incomplete download | Recommend delete |
| SHA-256-identical files | Keep one, delete the rest |
| Verified repair backup | Recommend delete when the live version is healthy |
| Unique photos, videos, documents, or source code | Keep or move |
| WSL, Docker, Claude/Codex runtime data | Keep or use the official app flow |

## Validation and contribution

The repository targets PowerShell 7. Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Repository.ps1
```

Read [CONTRIBUTING.md](./CONTRIBUTING.md). Do not expand dangerous automatic deletion or commit private paths or user data.

## License

MIT
