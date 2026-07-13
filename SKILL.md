---
name: windows-c-disk-cleaner
description: "Use when the user wants Windows disk governance on this machine: audit C:/E:/F: usage, interpret TreeSize results, rank cleanup/move/keep candidates, maintain closing records, and optionally clear only low-risk caches such as npm, bun, browser cache, crash logs, component caches, or recording artifacts. Also use when the user wants a TreeSize-driven auto-cache-clean pass that only touches a strict low-risk whitelist and reports skipped items instead of forcing deletion."
---

# Windows C Disk Cleaner

Use this skill for Windows disk cleanup work on this machine. Treat it as governance, not blind deletion.

## When to use

Trigger this skill when the user asks any of the following:

- "do a disk audit"
- "check what is taking space on C:"
- "based on TreeSize, make a cleanup plan"
- "clear a low-risk batch first"
- "I gave you a TreeSize report, just clear the safe caches"
- "auto clear junk caches from this TreeSize result"
- "find duplicate installers / repeated downloads / big recent files in Downloads or Desktop"
- "make this disk cleanup skill reusable from Claude Code"
- equivalent requests in Chinese about disk governance, C: usage, TreeSize-based planning, or low-risk cleanup

## Machine defaults

- Automatically discover available fixed disks, with the Windows system drive first.
- Audit the system drive first when the user only asks why it is tight.
- Prefer moving large user or tool data to a secondary drive before deleting.
- Focus on items larger than `1 GB` unless the user asks for smaller detail.
- Default flow is: audit -> plan -> execute only if the user asks.
- Low-risk execution is allowed only for explicit cache targets.
- Auto-cache-clean mode is conservative by default: do not migrate user data, do not uninstall software, do not stop processes unless the user explicitly asks.
- Cross-agent mode must rely only on local PowerShell scripts, JSON policy, and plain files so Codex and Claude Code can both reuse it.
- Keep a closing record under the user's Documents directory so future sessions can continue from facts instead of memory.
- Treat "strict safe clean", "confirmed clean", and "project work cleanup" as different layers. Do not blur them in reports.

## Recurring governance goals

Every non-trivial run should answer these questions in plain language:

- What changed since the last scan?
- What was actually deleted in this run, what was only skipped, and what is still left?
- Which large things are safe to delete now?
- Which things are not in the strict auto-clear whitelist, but can be cleared after the user explicitly confirms?
- Which large things should be moved to a secondary drive instead of deleted?
- Which things are app-managed or official-cleanup-only?
- Which things are important user data or environment data and should not be touched?
- If something can be deleted but will be re-downloaded later, which tool or project will trigger that re-download?
- Is `C:` still under pressure, or should we stop chasing small cache wins?

## Hard safety boundaries

Never hand-delete or recommend hand-deleting:

- `C:\Windows\WinSxS`
- `C:\Windows\System32`
- unknown files under system directories
- application install directories under `Program Files` or `Program Files (x86)` unless the user explicitly asks to uninstall software

System cleanup items such as the following must use official Windows cleanup paths:

- `C:\Windows\SoftwareDistribution`
- `C:\$WINDOWS.~BT`
- `C:\Windows.old`

## Workflow

### 1. Ingest context fast

If the user provides TreeSize output, use it first:

- screenshot
- pasted summary
- exported text or CSV

Use TreeSize only as a heat map. Always verify important claims locally with read-only commands before making recommendations or deletions.

If the user provides no TreeSize input, run the audit script directly.

Recommended fast path:

1. Launch TreeSize and scan `C:`
2. User sends screenshots or exports a CSV/text report
3. Read the TreeSize result first
4. Run targeted local verification only on the large areas

### 2. Run the audit

Use `scripts/audit_windows_disk.ps1` to gather:

- drive capacity and free space
- top-level directory rankings
- large root files
- key focus directories
- machine-specific hotspots
- low-risk cleanup candidates
- move-to-secondary-drive candidates
- action classes suitable for automation (`auto_clear`, `close_process_then_clear`, `suggest_only`, `official_or_app_only`, `never_touch`)

Use JSON output when you need structured post-processing.

### 3. Report in the same shape every time

Default response sections:

- executive summary
- detailed audit findings
- top cleanup candidates
- best move-to-secondary-drive candidates
- risk grouping
- next-step recommendation

For each actionable item, include:

- path
- size
- why it is large
- recommended action
- risk level
- estimated reclaim
- time cost
- rollbackability
- admin requirement

### 4. Use the 4-layer governance model

Always sort findings into these layers:

- `auto_clear`
  - strict low-risk cache whitelist
  - can be cleared automatically when the user asks to clean
- `confirm_then_clear`
  - low-risk or medium-low-risk cleanup targets that are not strict whitelist items
  - only clear after the user explicitly confirms in the current thread
  - examples: `C:\Windows\Temp` contents, user Temp contents, `uv\cache`, `.cache\whisper`
- `project_work_clean`
  - project build/work artifacts under a known project root
  - clear only after verifying the exact `work` path is inside a recognized project and the parent contains project markers such as `.git`, `package.json`, `pyproject.toml`, `android`, or `vite.config.ts`
  - explain that deleting it may require future rebuilds or re-downloads, but should not delete source files when scoped to the `work` directory
- `close_process_then_clear`
  - safe cache targets that are only worth clearing after related processes fully exit
  - typical examples are browser pure caches under Chrome or Edge `User Data`, and `uv\cache`
- `suggest_only`
  - large user or tool data that should be moved, reviewed, or handled manually
  - examples: WeChat file stores, WSL virtual disks, large project object stores
- `official_or_app_only`
  - paths that must be handled from Windows official cleanup, app settings, or uninstall flows
  - examples: `SoftwareDistribution`, `$WINDOWS.~BT`, WPS local data, `Roaming\npm`
- `never_touch`
  - protected areas that must never be auto-cleaned or recommended for hand deletion

For full-drive reviews, also add two human-facing groups:

- `move_or_archive`
  - safe to move away from `C:` or consolidate on a secondary drive without deleting the user's only copy
- `watch_for_two_weeks`
  - large runtime stores such as Docker that should only be removed after repeated evidence that no project or app is using them

### 5. Execute only the low-risk whitelist

Use `scripts/cleanup_low_risk.ps1` only when the user clearly asks to clean, or when the user explicitly wants TreeSize-driven auto-cache-clean behavior.

Allowed strict automatic cleanup targets:

- `npm-cache`
- `.bun\install\cache`
- AI tool browser recording folders
- Chrome pure cache directories
- Edge pure cache directories
- Chrome and Edge `Crashpad`
- Chrome and Edge `component_crx_cache`
- Chrome `OptGuideOnDeviceModel`

Do not auto-delete:

- WSL virtual disks
- coding tool snapshot/object stores
- messaging app data (WeChat, etc.)
- user documents, downloads, desktop files
- system update folders
- `Roaming\npm`
- `uv\cache`
- AI tool runtime caches

Confirmed-clean targets are a separate layer. If the user says "能删的先删", or if a scheduled automation is explicitly configured to clean low-risk items, the agent may clear `confirm_then_clear` items and must report each item as deleted, missing, skipped, or failed. Do not silently treat medium-risk or user-data items as low-risk.

Every execution run must:

1. Record C: free space before cleanup.
2. Execute only the requested layers.
3. Record C: free space after cleanup.
4. End with four lines: `已删`, `没删`, `还能删`, `为什么跳过`.

If Chrome or Edge is running and the user did not allow closing browsers, do not recursively scan browser cache trees. Report the browser cache roots as skipped because the browser is running.

## Large path forensics

When the user asks "what is this" or "can this be deleted", do not answer from the folder name alone. Inspect:

- exact path
- size
- created time, last write time, and last access time when available
- nearby project files such as `package.json`, `pyproject.toml`, `Dockerfile`, `docker-compose.yml`, `.venv`, `.git`, or installer metadata
- current processes or services that may use it
- whether it is a cache, project source, user document, installer/archive, virtual disk, app install, or app data
- deletion impact in one sentence
- move-to-secondary-drive impact in one sentence

Default path meanings:

- WSL virtual disks (`.vhdx` files) hold entire Linux environments. Do not hand-delete; export/unregister WSL if removal is approved.
- Docker Desktop data virtual disks should only be removed after uninstalling Docker officially.
- AI assistant app data directories (Claude, Codex, etc.) should not be deleted as a whole; only specific cache subdirectories are safe.
- WeChat and messaging app file stores are user data. Prefer app cleanup, migration, or no action.

## Docker and WSL rules

- If the user wants a cautious Docker decision, run a two-week watch:
  - check Docker Desktop service/process state
  - check WSL distro state
  - check Docker data virtual disk last write time and size
  - search active project roots for `Dockerfile`, `docker-compose.yml`, and `.devcontainer`
  - only recommend uninstall after two consecutive weekly reports show no meaningful usage
- Never hand-delete Docker or WSL virtual disks as the first step.

## Downloads and duplicate-package hunting

When the user asks to find repeated installers, `(1)`/`(2)` duplicate copies, or large recent files in personal folders such as Downloads and Desktop, use `scripts/find_duplicate_downloads.ps1`.

This mode is intentionally conservative:

- Default run is report-only. Nothing is deleted without `-Execute`.
- It lists two separate groups: `duplicate_copies` (files whose names carry copy markers like ` (1)`, ` - 副本`, ` - Copy`) and `large_recent_files` (files at or above `MinLargeFileMB` touched within `RecentDays`).
- A duplicate copy is only eligible for deletion when its original file still exists in the same folder (`original_exists = true`). Copies with no visible original are reported as `skip` and kept for manual review, because the `(1)` file may actually be the only copy.
- `large_recent_files` are always report-only and never auto-deleted. A big recent file is usually something the user just downloaded on purpose.
- Personal documents must still be treated as user data. Surface them, do not silently delete them, even when names look duplicated.

## Cross-agent reuse

When the user wants Claude Code reuse, especially with a third-party API provider, keep the workflow platform-neutral:

1. Prefer the wrapper `scripts/run_disk_governor.ps1`.
2. Use JSON output as the handoff contract.
3. Do not depend on Codex-only UI features, screenshots, or app-specific automation.
4. Read `references/claude-code.md` for exact Claude Code commands and output fields.

## Priority hotspots

Read `references/hotspots.md` when you need machine-specific guidance. It lists the common large paths and the expected action for each category.

## Scripts

- Launch TreeSize for a quick scan of `C:`:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\start_treesize_scan.ps1"
```

- Read a TreeSize export before full audit:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\read_treesize_input.ps1" -ReportPath "C:\path\to\treesize.csv" -EmitJson
```

- Run the TreeSize-first auto-cache-clean pass:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\run_from_treesize.ps1" -ReportPath "C:\path\to\treesize.csv" -EmitJson
```

- Cross-agent wrapper for Codex or Claude Code:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\run_disk_governor.ps1" -Mode report-only -EmitJson
```

- Write a reusable closing snapshot:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\write_closing_report.ps1" -EmitJson
```

- Hunt duplicate downloads and big recent files (report-only):

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\find_duplicate_downloads.ps1" -EmitJson
```

- Delete only redundant copies whose original still exists in the same folder:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\find_duplicate_downloads.ps1" -Execute
```

- Audit only:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\audit_windows_disk.ps1" -EmitJson
```

- Dry-run low-risk cleanup:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\cleanup_low_risk.ps1"
```

- Execute low-risk cleanup, including browser cache, and stop browsers if needed:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\cleanup_low_risk.ps1" -Execute -IncludeBrowserCaches -StopBrowserProcesses
```

- Execute strict low-risk cleanup plus user-confirmed extra cleanup without stopping browsers:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\cleanup_low_risk.ps1" -Execute -IncludeConfirmedCaches -IncludeBrowserCaches
```

## Output style

Human-facing output must be Simplified Chinese by default. Keep the language plain and use direct conclusions over jargon.

- Say what is worth touching first.
- Distinguish "可以直接清", "建议搬到别的盘", "只能软件内处理", and "不要碰".
- Explain "project dependency" in Chinese as: "项目依赖就是某个项目运行时需要的工具包/浏览器/库，删了不一定坏，但下次运行可能要重新下载或重新安装一次。"
- If a cache will definitely be re-downloaded soon, say in Chinese that deleting it may not be worth it.
- If something is blocked by admin rights or official Windows cleanup requirements, say that clearly in Chinese.
- If TreeSize input exists, say in Chinese that the result was used to speed up the audit.
- Markdown reports written by scripts must use Chinese titles, table headers, explanations, and next-step rules.
- JSON field names may stay English for cross-agent compatibility, but any human-readable values should be Chinese when practical.
- When reporting recent cleanup results, always include before/after free space, net C: delta, the largest freed item, and the largest remaining protected item.
- In auto-cache-clean mode, always separate:
  - `cleared`
  - `skipped-in-use`
  - `failed`
  - `confirm-then-clear`
  - `close-process-then-clear`
  - `suggest-only-large-items`
  - `official-or-app-only`
  - `never-touch`
