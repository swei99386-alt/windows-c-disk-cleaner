# Safe Execution Upgrade Design

## Goal

Make `windows-c-disk-cleaner` safe after real-world failures: report-only by default, explicit deletion intent, no automatic migration, bounded scans, and evidence-backed reports.

## Evidence Used

- The original Codex workflow required low-risk-only cleanup, skipped running applications, and a four-part closing summary.
- Antigravity records showed long recursive scans, a migration attempt that failed on long paths, and reports that could blur deletion failures with success.

## Design

### 1. Source of truth and rollout

The public repository is the source of truth. Changes are tested and pushed on `chore/public-release-hardening`, then installed as backed-up copies for Claude Code, Codex, and Antigravity. Existing local directories are renamed with a timestamp before replacement; no directory is deleted in place.

### 2. Execution gate

`report-only`, `audit-only`, and closing reports remain non-mutating. `safe-clean`, `confirmed-clean`, and `project-work-clean` require the new `-Execute` switch at the top-level runner. Calling an execution mode without it exits with a clear message and makes no changes.

Migration is not an execution mode. The Skill may only report that migration is a separate, manually approved task. It must never create a junction, run `Move-Item`, or invoke Robocopy as part of disk cleaning.

### 3. Bounded scans

Browser cache discovery is skipped whenever Chrome or Edge is running, in both planning and execution. The default workflow does not recursively scan a browser profile. The documentation instructs agents to scan targeted paths first and stop a path-level scan when it exceeds the supplied time budget.

### 4. Evidence-backed cleanup report

Every cleanup result includes: before/after free space for the system drive, path, status, before/after size when available, and a reason. A result is counted as reclaimed only when its status is `deleted` or `cleared` and the recorded size difference is positive. `failed`, `missing`, and `skipped-in-use` are never presented as successful cleanup.

### 5. Protected data

The policy explicitly protects messaging data, desktop/download/documents, Claude/Codex/Gemini application state, WSL/Docker virtual disks, and all app-managed paths. No new automatic-clean path is added.

## Acceptance Criteria

- Execution modes fail safely without `-Execute`.
- Report-only modes still run without `-Execute`.
- Browser profile recursion is skipped if the browser is running.
- Tests cover the gate and policy guardrails without deleting real files.
- README and SKILL.md clearly state migration is not automated.
- Installed copies are backed up before synchronization.
