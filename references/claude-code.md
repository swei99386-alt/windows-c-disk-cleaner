# Claude Code reuse

This skill is safe to reuse from Claude Code, including Claude Code configured with a third-party API provider or Anthropic's official API, because the operational surface is local PowerShell scripts and JSON policy files. No Codex UI feature, browser session, MCP server, or model-provider-specific API is required.

## Entry point

Prefer this wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\run_disk_governor.ps1" -Mode report-only -EmitJson
```

Modes:

- `audit-only`: read-only disk audit, no cleanup script is invoked.
- `report-only`: audit plus dry-run cleanup report.
- `safe-clean`: executes only `auto_clear` and cache-scan policy targets.
- `confirmed-clean`: executes confirmed cache cleanup after the user says "能删的先删" or equivalent. It clears Windows Temp contents, user Temp contents, uv cache, Whisper cache, and Chrome/Edge pure cache directories without closing browsers.
- `project-work-clean`: executes only guarded deletion of explicit project `work` directories passed with `-ProjectWorkPath`.

## Safe-clean command

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\run_disk_governor.ps1" -Mode safe-clean -EmitJson
```

## Confirmed-clean command

Use only after the user confirms low-risk cleanup in the current thread:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\run_disk_governor.ps1" -Mode confirmed-clean -EmitJson
```

To include a verified project build/work directory:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner\scripts\run_disk_governor.ps1" -Mode confirmed-clean -ProjectWorkPath "C:\Users\YOURUSERNAME\Documents\Projects\project-name\work" -EmitJson
```

The wrapper rejects project work paths that do not end in `\work` or whose parent does not look like a project root (no `.git`, `package.json`, `pyproject.toml`, `android`, or `vite.config.ts`).

## Contract for agents

Use the JSON fields as the handoff contract:

- `before_drives`, `after_drives`, `drive_delta`: space before/after cleanup.
- `cleaned`: paths actually deleted.
- `skipped_in_use`: safe targets that were blocked by running processes or access.
- `failed`: attempted targets that failed.
- `missing`: already absent targets.
- `all_results`: complete per-target status when using `confirmed-clean` or `project-work-clean`.
- `close_process_then_clear`: useful targets that need a process to exit first.
- `suggest_only_large_items`: large user data or tool data; do not delete automatically.
- `official_or_app_only`: use Windows cleanup, app settings, package managers, or uninstallers.
- `never_touch`: protected paths.

Never delete paths outside the policy whitelist during `safe-clean`. Treat AI assistant runtime bundles, messaging app data, office app data, global npm tools, Docker program files, WSL program files, browser profile roots, and Windows system directories as report-only unless the user explicitly asks for an app-specific uninstall or migration workflow.

For Claude Code agents using third-party API providers: run the same PowerShell commands, parse the JSON, and respond in Chinese. Do not assume access to Codex memory, Codex automations, or Codex plugin state.
