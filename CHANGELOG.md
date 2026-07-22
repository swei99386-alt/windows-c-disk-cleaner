# Changelog

## [0.2.0] - 2026-07-23

### Added

- Plain-language Chinese and English landing pages for ordinary Windows users.
- An anonymized real cleanup case and a copyable prompt library.
- Skills CLI installation and remote discovery instructions.
- Search terms for C盘满了, Windows disk cleanup, C/E drive cleanup, Downloads, duplicate files, installers, and repair backups.

### Changed

- Reframed cleanup decisions around recovery cost instead of blanket conservatism.
- Added reference-path protection and re-validation for migrated folders before deletion.

## [Unreleased]

### Changed

- Unified public skill identifier.
- Removed machine-specific disk and user paths.
- Hardened the installer.
- Added Windows CI and repository validation.
- Require `-Execute` for every cleanup mode in the unified runner.
- Treat application migration as a separate manual task, never automated cleanup.
- Skip browser-profile recursion while a browser is running.
