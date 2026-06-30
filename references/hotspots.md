# Machine Hotspots

This file captures the main disk pressure points on a typical Windows developer machine and the default action for each. Adapt the paths to match your own setup.

## Global rules

- Prefer a secondary drive (e.g. `E:`) for migration targets.
- Default threshold for "large" is `1 GB`.
- Treat caches as first-class cleanup targets.
- Treat user data and virtual disks as migration candidates before deletion.
- Treat `C:` as healthy when it has roughly `50 GB` free. Below `40 GB`, start cleanup planning. Below `20 GB`, prioritize urgent space recovery.
- Always write or update a closing record after a long cleanup session.

## Known high-value targets

### Low-risk clearable caches

- `%USERPROFILE%\AppData\Local\npm-cache`
  - Category: developer cache
  - Action: clear
  - Risk: low

- `%USERPROFILE%\.bun\install\cache`
  - Category: developer cache
  - Action: clear
  - Risk: low

- AI tool browser recording folders (e.g. `.gemini\antigravity\browser_recordings`)
  - Category: AI tool artifacts
  - Action: clear or move if the user wants to keep them
  - Risk: low

- `%USERPROFILE%\AppData\Local\Google\Chrome\User Data\OptGuideOnDeviceModel`
  - Category: browser model cache
  - Action: clear
  - Risk: low to medium

- Chrome or Edge pure cache directories:
  - `Cache`
  - `Code Cache`
  - `GPUCache`
  - `DawnCache`
  - `GrShaderCache`
  - `ShaderCache`
  - `Media Cache`
  - `Service Worker\CacheStorage`
  - Action: clear
  - Risk: low

### Confirm-after-report cleanup targets

These are not strict auto-clear items. They should appear in every audit report when present, and can be cleared only after the user explicitly confirms in the current conversation.

- `C:\Windows\Temp`
  - Category: system temp contents
  - Action: clear contents only, never delete the folder itself
  - Risk: low, but may require admin rights and may skip in-use files

- `%USERPROFILE%\AppData\Local\Temp`
  - Category: user temp contents
  - Action: clear contents only
  - Risk: low, but may skip in-use files

- `%USERPROFILE%\AppData\Local\uv\cache`
  - Category: developer cache
  - Action: clear after confirmation
  - Risk: low; future Python runs may re-download packages

- `%USERPROFILE%\.cache\whisper`
  - Category: AI model cache
  - Action: clear after confirmation if speech recognition is not needed soon
  - Risk: low; models may re-download later

### Medium-risk audit-first targets

- Project build/work artifact directories (e.g. `\work` inside a project root)
  - Category: project build artifact
  - Action: verify the exact path ends with `\work` and the parent has project markers before deletion
  - Risk: low to medium; source files should stay, but future rebuilds may need to download dependencies again

- `%USERPROFILE%\.local\share\opencode`
  - Category: local snapshot/object store
  - Action: inspect before deleting
  - Risk: medium

- `%USERPROFILE%\AppData\Roaming\npm`
  - Category: globally installed CLI tools
  - Action: remove unused global packages rather than blind deletion
  - Risk: medium

- `%USERPROFILE%\AppData\Local\pnpm\store`
  - Category: shared package store
  - Action: prefer `pnpm store prune`; do not blindly delete the whole store while projects may use it
  - Risk: medium

- `%USERPROFILE%\AppData\Local\wsl\...\ext4.vhdx`
  - Category: WSL virtual disk
  - Action: move or export/import, not blind delete
  - Risk: medium

- Docker Desktop data virtual disk (`docker_data.vhdx`)
  - Category: Docker Desktop virtual disk
  - Action: watch for two weeks, then uninstall/cleanup officially if unused
  - Risk: high if hand-deleted

### Move-to-secondary-drive candidates

- `%USERPROFILE%\Documents\WeChat Files`
- `%USERPROFILE%\xwechat_files`
- `%USERPROFILE%\Desktop`
- `%USERPROFILE%\Downloads`
- WSL virtual disks under `AppData\Local\wsl`

### Archive-review candidates

These are usually better treated as archive cleanup, not cache cleanup. Explain what each large file is, when it appears to have been last used, and whether deleting it loses the only copy.

- Large download archives on secondary drives (old installers, game backups, ISO files, etc.)
- Migration archives from earlier drive reorganizations
- Music and video download directories from streaming apps

## Protected user/work data

Do not recommend blind deletion for:

- AI assistant app state (Claude Desktop, Codex, etc.)
- Large AI runtime bundles (e.g. `vm_bundles`); handle only as a separate migration or shrink task
- Messaging app chat data (WeChat, etc.)
- Office app state (WPS, Microsoft Office, etc.)
- Personal documents, photos, student and work files
- `.ssh`, `.docker`, WSL VHDX, Docker VHDX, and browser profile roots

### Official-cleanup-only items

- `C:\Windows\SoftwareDistribution`
- `C:\$WINDOWS.~BT`
- `C:\Windows.old`

These should be surfaced in reports, but execution should use official Windows cleanup tooling.

## Install directories worth auditing, not deleting directly

- `C:\Program Files\Docker`
- `C:\Program Files\WSL`
- `C:\Program Files\Google`
- Office installation directories

Report their size and recent activity, but do not remove them directly.
