# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is not an application — it is a **Claude Code / Codex / Antigravity Skill package** for governing disk space on a specific Windows machine. It ships as a `SKILL.md` (the skill definition read by AI coding assistants) plus a set of standalone PowerShell scripts, a JSON policy file, and reference docs. There is no build, no test suite, and no package manager — everything is plain PowerShell (`.ps1`) invoked directly.

The scripts are written and tested to run on Windows (PowerShell 5.1+ / `powershell.exe`), but this repo is frequently edited from non-Windows dev/CI environments. There is no way to actually execute the scripts against a real `C:` drive from this environment — treat changes as "read and reason about it," not "run it and see."

## Repository layout

- `SKILL.md` — the actual skill definition (frontmatter `name`/`description` + full workflow instructions). This is the primary source of truth for *behavior*: when to trigger, the 4-layer risk model, safety boundaries, output format. Read this before changing any script's behavior, and keep it in sync with script changes.
- `config/auto-clean-policy.json` — the whitelist/blacklist policy consumed by the scripts at runtime (`auto_clear_paths`, `close_process_then_clear_paths`, `suggest_only_roots`, `never_touch_roots`, `official_only_paths`, `app_managed_paths`, `watch_for_two_weeks`, thresholds). Paths use the literal placeholder `YOURUSERNAME`, substituted by `install.ps1` at install time — never hardcode a real username into this file in the repo.
- `scripts/` — all PowerShell logic (see Architecture below).
- `references/hotspots.md` — human-readable catalog of known large-path categories on the target machine and the expected action for each (mirrors/extends the policy JSON in prose form).
- `references/claude-code.md` — the cross-agent contract: which JSON fields mean what, which `run_disk_governor.ps1 -Mode` to use, and rules for agents using third-party API providers.
- `agents/openai.yaml` — Codex-compatible agent interface descriptor (display name, default prompt).
- `install.ps1` — one-shot installer: substitutes `YOURUSERNAME` in the policy JSON with `$env:USERNAME`, then symlinks (or copies, if symlink creation fails without dev mode/admin) this folder into `~\.claude\skills`, `~\.codex\skills`, and `~\.gemini\config\skills`.
- `README.md` / `README_EN.md` — Chinese (primary) and English project overviews; keep both in sync when changing behavior or scripts.

## Architecture: how the scripts compose

`scripts/run_disk_governor.ps1` is the single cross-agent entry point. It is a thin dispatcher over `-Mode`, invoking other scripts as child `powershell` processes and passing through JSON:

- `audit-only` → `audit_windows_disk.ps1 -EmitJson` (read-only)
- `report-only` (default) → `run_from_treesize.ps1` (no `-Execute`)
- `safe-clean` → `run_from_treesize.ps1 -Execute` (strict `auto_clear` whitelist only)
- `confirmed-clean` → `cleanup_confirmed_safe.ps1 -Execute -IncludeConfirmedCaches -IncludeBrowserCaches`
- `project-work-clean` → `cleanup_confirmed_safe.ps1 -Execute -ProjectWorkPath <path>` (guarded deletion of a specific project's `work` dir)
- `closing-report` / `deep-closing-report` → `write_closing_report.ps1` (add `-DeepRootScan` for deep mode)

Other scripts and their roles:

- `audit_windows_disk.ps1` — the main read-only scanner. Reads `config/auto-clean-policy.json`, walks a drive (`-RootDrive`, default `C`), builds a hardcoded candidate list (`New-AuditRow` calls) of known hotspot paths annotated with category/risk/action_class/estimated reclaim, ranks top-level directories and root large files, and detects blocking processes (e.g. `chrome`, `msedge`, `uv`) holding a path open. Can optionally ingest a TreeSize CSV/text export via `-TreeSizeReportPath` to seed `tree_size_input`. Emits one big JSON report (`-EmitJson`) with fields like `candidates`, `auto_clear_candidates`, `confirm_then_clear_candidates`, `close_process_then_clear_candidates`, `official_or_app_only_candidates`, `never_touch_candidates`, `blocking_processes`.
- `run_from_treesize.ps1` — orchestrates `read_treesize_input.ps1` (if a report path is given) + `audit_windows_disk.ps1`, and optionally `cleanup_low_risk.ps1 -Execute` when `-Execute` is passed. This is what `safe-clean`/`report-only` modes actually call.
- `read_treesize_input.ps1` — parses a TreeSize CSV or text export into normalized rows, used only as a "heat map" to speed up auditing (never trusted blindly; the skill workflow always re-verifies with local read-only commands).
- `cleanup_low_risk.ps1` — executes only the strict `auto_clear_paths` whitelist from the policy JSON (npm-cache, bun cache, AI tool recording folders, Chrome/Edge pure cache dirs, Crashpad, component_crx_cache, etc.). `-IncludeBrowserCaches` / `-IncludeConfirmedCaches` / `-StopBrowserProcesses` widen scope; still report-only unless `-Execute` is passed.
- `cleanup_confirmed_safe.ps1` — executes the `confirm_then_clear` layer (Windows/user Temp contents, `uv\cache`, Whisper cache, etc.) — only meant to run after the user explicitly confirms in-thread. Also handles `-ProjectWorkPath`, which is validated: the path must end in `\work` and its parent must contain a project marker (`.git`, `package.json`, `pyproject.toml`, `android`, `vite.config.ts`) before anything under it is deleted.
- `find_duplicate_downloads.ps1` — independent tool for Downloads/Desktop: finds `(1)`/`- 副本`/`- Copy` duplicate files (deletable via `-Execute` **only** when the original still exists alongside it) and lists `large_recent_files` (always report-only, never auto-deleted).
- `write_closing_report.ps1` — takes a before/after disk snapshot across `-Drives` (default `C`, `E`, `F`) and writes a Markdown + JSON closing record to `-OutputDir` (default `E:\disk-audit-reports`), so a later session can pick up from facts instead of memory. `-DeepRootScan` does a more expensive top-level scan.
- `start_treesize_scan.ps1` — locates a local TreeSize Free install and launches it against `-TargetPath` (default `C:\`); purely a convenience launcher, no output contract.

All scripts follow the same conventions: `[CmdletBinding()]` + typed `param()` block, `-EmitJson` to serialize the result via `ConvertTo-Json`, and — except for the audit/read scripts, which are inherently read-only — an explicit `-Execute` switch gated in front of any actual deletion (default is always dry-run/report-only).

## The risk model (must be preserved in any script change)

Every path the tooling touches is classified into exactly one of these layers (defined in `SKILL.md` and mirrored in `action_class` fields in script output and in `config/auto-clean-policy.json`):

1. `auto_clear` — strict whitelist, safe to delete without asking.
2. `confirm_then_clear` — low/medium-low risk, but requires explicit in-thread user confirmation first.
3. `close_process_then_clear` — safe only after the owning process (browser, `uv`) has exited.
4. `project_work_clean` — project build artifacts under a verified `...\work` directory inside a real project root.
5. `suggest_only` — large user/tool data to move or review manually, never auto-deleted.
6. `official_or_app_only` — must go through Windows' own cleanup tools, app settings, or an uninstaller (e.g. `SoftwareDistribution`, `pnpm store prune`, global npm packages).
7. `never_touch` — protected system paths (`C:\Windows`, `Program Files`, `pagefile.sys`) that are never deleted or recommended for deletion, even by hand.

Never blur these layers when editing scripts or docs — e.g. don't let `cleanup_low_risk.ps1` reach into `confirm_then_clear` targets, and don't let `never_touch_roots` become deletable through any code path. `SKILL.md` also mandates human-facing output in **Simplified Chinese**, plain language over jargon, and always reporting free space before/after any execution run.

## Working in this repo

- There's nothing to "build" or "lint" — validate PowerShell changes by reading them carefully (parameter types, `-WhatIf`-style dry-run defaults, path-quoting with `-LiteralPath`) since there is no Windows execution environment available here.
- Any new low-risk deletable path must be added to `config/auto-clean-policy.json`'s `auto_clear_paths` (using the `YOURUSERNAME` placeholder, never a real path with a concrete username) *and* reflected in `SKILL.md`'s "Allowed strict automatic cleanup targets" list and `references/hotspots.md`, or the different docs/scripts will disagree about what's safe.
- When adding a new script mode or parameter, update `references/claude-code.md`'s "Contract for agents" section — that file is the explicit machine-readable interface other agents (Codex, third-party API Claude Code) rely on.
- Keep `README.md` (Chinese, primary) and `README_EN.md` (English) in sync — this project is Chinese-first, and human-facing output from the scripts themselves is Chinese by design (`human_report_language: zh-CN` in the policy).
