# Safe Execution Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent unconfirmed cleanup or migration while producing auditable, bounded disk-cleanup results.

**Architecture:** Add one execution gate at `run_disk_governor.ps1`, retain the existing low-risk cleaner, and strengthen the policy/documentation boundary. Repository tests use isolated temporary paths and never call cleanup with `-Execute`.

**Tech Stack:** PowerShell 7, JSON policy, GitHub Actions.

## Global Constraints

- Default behavior is report-only.
- No migration, junction, Robocopy, or `Move-Item` logic is added to the Skill.
- No automatic-clean whitelist is expanded.
- Tests must not remove real files or scan a runner's disk.

---

### Task 1: Gate top-level execution modes

**Files:**

- Modify: `scripts/run_disk_governor.ps1`
- Test: `tests/Test-Repository.ps1`

**Interfaces:**

- Produces: `-Execute` switch on `run_disk_governor.ps1`.
- Behavior: `safe-clean`, `confirmed-clean`, and `project-work-clean` throw unless `-Execute` is supplied.

- [ ] Add `[switch]$Execute` to the runner parameters.
- [ ] Define `$executionModes = @('safe-clean', 'confirmed-clean', 'project-work-clean')`.
- [ ] Before dispatching a mode, throw `Execution mode '<mode>' requires -Execute after explicit user confirmation.` when `$Mode` is an execution mode and `$Execute` is false.
- [ ] Preserve `report-only`, `audit-only`, and closing-report behavior.
- [ ] Test the blocked command in a temporary profile and assert a non-zero exit code without creating files.

### Task 2: Bound browser-cache scans and evidence reporting

**Files:**

- Modify: `scripts/cleanup_low_risk.ps1`
- Modify: `scripts/run_from_treesize.ps1`
- Test: `tests/Test-Repository.ps1`

**Interfaces:**

- Consumes: the existing `browser_cache_dir_names` policy array.
- Produces: an explicit `browser-running-scan-skipped` result before any browser-profile recursion.

- [ ] Return one skipped browser-root result when Chrome or Edge is running, regardless of execution mode.
- [ ] Do not call `Get-BrowserCacheTargets` for a running browser.
- [ ] Keep `deleted`, `cleared`, `failed`, `missing`, and `skipped-in-use` separate in JSON output.
- [ ] Add repository checks that execution tests cannot invoke `-Execute`, `safe-clean`, `confirmed-clean`, or `project-work-clean`.

### Task 3: Update public safety contract

**Files:**

- Modify: `SKILL.md`
- Modify: `README.md`
- Modify: `README_EN.md`
- Modify: `config/auto-clean-policy.json`
- Modify: `CHANGELOG.md`

- [ ] State that migration is a separate manually approved task and is never automated by this Skill.
- [ ] State that only positive, measured size differences are reported as reclaimed.
- [ ] Add messaging data and AI application state to the policy's protected hints without adding any deletion paths.
- [ ] Keep Chinese and English documentation structurally aligned.

### Task 4: Verify, commit, publish, and synchronize

**Files:**

- Modify: `install.ps1` only if needed for safe backed-up synchronization.

- [ ] Run `pwsh -NoProfile -File .\tests\Test-Repository.ps1`.
- [ ] Run `pwsh -NoProfile -File .\install.ps1 -WhatIf` with an isolated temporary user profile.
- [ ] Run `git diff --check`.
- [ ] Commit the upgrade, push `chore/public-release-hardening`, then run the installer with `-Force` for each installed assistant so the previous directory is timestamp-backed-up.
