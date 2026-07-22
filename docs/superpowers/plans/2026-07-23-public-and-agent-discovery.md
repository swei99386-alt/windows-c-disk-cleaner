# Public and Agent Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish a complete ordinary-user entry point and an agent-discovery path for `windows-c-disk-cleaner`, then release v0.2.0.

**Architecture:** Keep the root `SKILL.md` as the only canonical skill artifact. Turn the README files into landing pages, move supporting proof and prompts into focused Markdown pages, and use GitHub release metadata plus Skills CLI verification as the distribution layer.

**Tech Stack:** Markdown, YAML, PowerShell 7, GitHub CLI, Skills CLI.

## Global Constraints

- Publish no personal paths, filenames, chat content, or identifiers.
- State that 12.49 GB is one verified example, not an expected result.
- Do not add a second `SKILL.md` or a duplicate skill package.
- Run `tests/Test-Repository.ps1` and `npx skills add swei99386-alt/windows-c-disk-cleaner --list` before releasing.

---

### Task 1: Build the ordinary-user entry point

**Files:**
- Modify: `README.md`, `README_EN.md`
- Create: `docs/real-cleanup-case.md`, `docs/copyable-prompts.md`

**Produces:** A public landing page with a simple promise, a real anonymized case, and prompts that can be pasted into Claude Code or Codex.

- [ ] **Step 1: Add a plain-language opening and three-step quick start to both README files.**

  The opening must state: “find what fills C/E, decide delete/keep/move by recovery cost, and never delete before showing the exact list.” The quick start must include the repository clone command and the Skills CLI command.

- [ ] **Step 2: Add `docs/real-cleanup-case.md`.**

  Include the verified numbers: 11.13 GB from installers and exact duplicates, 1.36 GB from a confirmed old copy, and 12.49 GB total. State that WSL, Docker, Claude runtime data, unique files, and the active Windows Desktop were protected. State that a migrated folder name is not proof of being the live Desktop and that the skill now verifies live paths immediately before deletion.

- [ ] **Step 3: Add `docs/copyable-prompts.md`.**

  Include three Chinese prompts and their English equivalents: audit-only, produce an exact deletion manifest, and execute a confirmed manifest with before/after free space.

- [ ] **Step 4: Verify links and privacy.**

  Run `rg -n "C:\\Users\\|E:\\|\.pre-repair" README.md README_EN.md docs/copyable-prompts.md docs/real-cleanup-case.md`.

  Expected: no output.

### Task 2: Make the skill discoverable to agents

**Files:**
- Modify: `SKILL.md`, `agents/openai.yaml`, `README.md`, `README_EN.md`

**Produces:** Searchable trigger language, a standard Skills CLI installation path, and agent-specific promises that match real behavior.

- [ ] **Step 1: Add bilingual real-world trigger terms to `SKILL.md` description.**

  Include C drive full, C盘满了, Windows disk cleanup, C/E drive cleanup, large files, duplicate files, Downloads, installers, repair backups, and cleanup manifest. Keep the name `windows-c-disk-cleaner` unchanged.

- [ ] **Step 2: Update `agents/openai.yaml`.**

  Make `short_description` explain the recovery-cost rule in one sentence. Make `default_prompt` request an exact deletion manifest and before/after free space.

- [ ] **Step 3: Add the standard installation command to both README files.**

  Use exactly: `npx skills add swei99386-alt/windows-c-disk-cleaner -g -a codex -a claude-code`.

- [ ] **Step 4: Verify repository discovery from the public remote.**

  Run: `npx skills add swei99386-alt/windows-c-disk-cleaner --list`.

  Expected: the output lists `windows-c-disk-cleaner` from the root `SKILL.md`.

### Task 3: Validate, publish, and release

**Files:**
- Modify: `CHANGELOG.md`

**Produces:** A tested commit on `main`, tag `v0.2.0`, and a GitHub Release with installation and change notes.

- [ ] **Step 1: Add an Unreleased/v0.2.0 entry to `CHANGELOG.md`.**

  List the ordinary-user guides, case study, prompt library, discovery wording, and recovery-cost decision model.

- [ ] **Step 2: Run repository validation.**

  Run: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/Test-Repository.ps1`.

  Expected: `PASS: repository validation`.

- [ ] **Step 3: Commit only the documentation and discovery files.**

  Run `git add README.md README_EN.md SKILL.md agents/openai.yaml CHANGELOG.md docs/real-cleanup-case.md docs/copyable-prompts.md docs/superpowers/specs/2026-07-23-public-and-agent-discovery-design.md docs/superpowers/plans/2026-07-23-public-and-agent-discovery.md` and commit with message `release: prepare v0.2.0 discovery update`.

- [ ] **Step 4: Push to `main`, tag, and create the release.**

  Push the commit, create annotated tag `v0.2.0`, push the tag, then create a GitHub release titled `v0.2.0 — recovery-cost disk governance` whose body links to the case study, prompt library, and installation command.

## Self-review

- [ ] Every ordinary-user page says what is deleted, what is protected, and that deletion requires an exact manifest.
- [ ] Every agent-facing entry uses the same recovery-cost language as `SKILL.md`.
- [ ] No private path or personal filename is present.
- [ ] The remote Skills CLI discovery check and repository test pass before release.
