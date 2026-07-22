---
name: windows-c-disk-cleaner
description: "Windows C/E disk cleanup and disk-space governance for requests such as C盘满了, C盘清理, Windows disk cleanup, C/E drive cleanup, large files, duplicate files, Downloads, installers, repair backups, or a deletion manifest. Audit, explain, and clean using a recovery-cost-first rule: recommend delete, keep, or move, then execute only after confirmation of exact paths."
---

# Windows Disk Governor

Use this skill to make a decision, not to turn uncertainty into a burden for the user.

## Core rule: recovery cost first

For every candidate, compare two costs:

`deletion cost = real time/money/data loss needed to get it back`

`retention cost = occupied space + future management cost`

Delete when deletion cost is low and the item is not a live dependency. “Cannot prove 100% certainty” is not a reason to label an ordinary installer high risk.

The agent owns the default recommendation. Ask the user only when the loss is genuinely irreversible or the scope changes materially.

## Decision classes

Use one of these explicit conclusions. Do not use a vague `先审阅` when evidence supports a stronger conclusion.

| Class | Default conclusion | Evidence required |
|---|---|---|
| `delete_default` | Recommend deletion | Public installer/downloader/APK, incomplete download, or disposable cache; not inside a live app installation or active update path |
| `dedupe_keep_one` | Delete all but one | SHA-256 identical content; state which exact copy remains |
| `delete_verified_backup` | Recommend deletion | Named backup/repair snapshot is a duplicate of an independently verified live location; live app/path is healthy |
| `move_or_archive` | Keep one copy, move from C: | Personal data is recoverable but expensive to recreate, such as course material or historical project assets |
| `app_or_official` | Use app/Windows cleanup flow | App data, Windows update data, Docker/WSL data, or an installed program |
| `keep` | Keep | Unique personal data or active runtime dependency |

### Default examples

- Delete by default: downloaded `.exe`, `.msi`, `.apk`, `.downloading`, `.part`, `.crdownload`; duplicate installers; completed copies with identical SHA-256.
- Keep one, delete the rest: identical ZIP/RAR/DOCX/PDF/photo/video files after hash verification.
- Delete a repair backup: e.g. `App.pre-repair-*` only after verifying the normal app data directory exists, is distinct, and the app is currently healthy. Explain that the only lost capability is rollback to that old broken/previous state.
- Keep or archive: source video, user-created documents, project source, chat attachments, unique course files.
- Never hand-delete: WSL `.vhdx`, Docker data disks, Claude/Codex runtime stores, Windows core files, or app files under `Program Files`. Use the app's uninstall/migration flow instead.

## Required forensic checks

Before recommending deletion, inspect the exact path, size, type, last write, and relationship to a replacement or live consumer.

For a claimed duplicate or backup, verify the claim, not just the name:

1. Hash files for identical-content claims.
2. For a repair backup, compare its top-level structure and size to the active path; check the active app process/path where possible.
3. For a moved Desktop/Documents folder, query the actual Windows known-folder path and junction target. A directory named “Desktop-某人” is **not** automatically the active Windows Desktop.
4. For a migrated copy, compare relative file paths and sizes. Do not delete it solely because another folder has a similar name.
5. Re-check immediately before execution; temporary Office files or a changed file set invalidate a prior “complete duplicate” conclusion.
6. Mark the live Desktop, current project roots, and the chosen retained copy as `reference paths`: compare against them, but never let an automatic deletion action modify them.

## Workflow

1. Snapshot free space on every fixed disk; inspect C: first when C: is under pressure.
2. Use TreeSize as a heat map if available; confirm important paths locally. Run `scripts/audit_windows_disk.ps1 -EmitJson` for a structured audit and `scripts/find_duplicate_downloads.ps1 -EmitJson` for downloads/duplicates.
3. Classify each large candidate with a default conclusion from the table above.
4. Produce a short “明确建议删除清单” before asking for execution. Each row must include: exact path/scope, reclaim estimate, why it can be recovered, what remains, and deletion impact.
5. Put only true judgment calls in a separate small section: unique data, unclear ownership, or unknown runtime use. Do not make the user arbitrate ordinary installers.
6. Execute only after current-thread confirmation of the exact candidate list. Re-validate the exact paths just before deleting.
7. Record before/after free space and report: `已删` / `没删` / `还能删` / `为什么跳过`.

### Tool roles

- Use TreeSize/WizTree-style analysis only to locate hotspots quickly.
- Use SHA-256 (or a duplicate finder such as Czkawka) to prove exact duplicates and protect the retained reference path.
- Let this skill make the recovery-cost decision and issue the deletion manifest; a scanner must not become a blind deleter.
- Use Windows Storage Sense only for system-drive temporary files, Recycle Bin rules, and cloud offloading. Do not configure it to age-delete Downloads: it cannot distinguish a disposable installer from a unique user file.

## Execution boundaries

- A request such as “删了” applies only to the immediately listed, exact scope. If a new path appears, ask again.
- Prefer grouping public installers by one verified Downloads folder; never use a broad drive-wide extension deletion.
- A failed or interrupted delete can still have completed. After interruption, stop further actions and read back the exact target state before claiming success or failure.
- Do not close the user's apps, take over mouse/keyboard, uninstall software, or delete browser/user documents unless the user explicitly requested that scope.
- If a deletion is permanent, say so before execution. Do not claim it is recoverable from the Recycle Bin unless it actually is.

## Hard boundaries

Never hand-delete or recommend hand-deleting:

- `C:\Windows\WinSxS`, `C:\Windows\System32`, unknown system files, `pagefile.sys`, or `swapfile.sys`
- application directories in `Program Files` / `Program Files (x86)`
- WSL virtual disks, Docker data virtual disks, AI-assistant runtime virtual disks, messaging app stores, or user-profile directories as a whole

Use official/app flows for `C:\Windows\SoftwareDistribution`, `C:\Windows.old`, `$WINDOWS.~BT`, WPS/WeChat cleanup, Docker uninstall, and WSL export/unregister.

## Report language

Use plain Simplified Chinese. Lead with the answer:

- `建议删：...，可释放约 ...；删后 ...。`
- `建议留：...，因为 ...。`
- `建议搬走：...，因为 ...。`

Avoid “高风险” as a substitute for analysis. Risk means irreversible loss or live-system breakage, not merely that the agent has not looked yet.

## Scripts

- Audit: `scripts/audit_windows_disk.ps1 -EmitJson`
- Find duplicate downloads: `scripts/find_duplicate_downloads.ps1 -EmitJson`
- Strict cache cleanup: `scripts/cleanup_low_risk.ps1` (execute only with the script's explicit execution switch)
- Closing record: `scripts/write_closing_report.ps1 -EmitJson`

Keep JSON field names stable for Codex/Claude Code reuse; all user-facing descriptions must be Chinese.
