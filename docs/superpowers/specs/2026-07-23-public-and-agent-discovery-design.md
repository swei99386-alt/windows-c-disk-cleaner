# Public and Agent Discovery Design

## Goal

Make `windows-c-disk-cleaner` understandable to a Windows user in one minute and discoverable/installable by an agent user without reading the source code.

## Two audiences

### Ordinary Windows users

They need a simple answer to three questions: what problem this solves, what it will not damage, and what they should say to an AI agent. The repository homepage will lead with these answers, then link to a real anonymized cleanup case and a copyable prompt page.

### Agent and developer users

They need searchable trigger language, one standard `npx skills` installation command, and proof that the public GitHub repository can be listed by the Skills CLI. The root `SKILL.md` remains the single canonical skill entry; no duplicate skill directory is created.

## Information architecture

- `README.md` and `README_EN.md`: landing pages with a plain-language promise, a three-step quick start, both audience paths, and the Skills CLI command.
- `docs/real-cleanup-case.md`: an anonymized, evidence-backed case showing 12.49 GB reclaimed, what was removed, what was protected, and the rule change caused by the migration-path mistake.
- `docs/copyable-prompts.md`: Chinese and English prompts for audit, deletion-manifest review, and confirmed cleanup.
- `SKILL.md` and `agents/openai.yaml`: bilingual discovery language using real user phrases such as C drive full, Windows disk cleanup, duplicate files, Downloads, installers, repair backups, and C/E drive cleanup.

## Guardrails

- Do not publish local usernames, absolute user paths, chat data, or private filenames.
- Do not claim that the skill has users, stars, or guaranteed reclaimed space.
- Describe the 12.49 GB case as one verified local example, not a promised result.
- Keep automatic cleanup limited to temporary/cache categories; the AI must produce an exact deletion manifest before deleting personal-folder items.

## Release

Publish the documentation and discovery update to `main`, verify `npx skills add swei99386-alt/windows-c-disk-cleaner --list`, then create GitHub release `v0.2.0` with the public-facing summary.
