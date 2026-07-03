# Windows C Drive Cleaner (AI-Agent Skill)

[简体中文](./README.md) | English

> Clean your Windows C drive and entire hard disk intelligently through natural language conversations with AI—targeting developer caches, AI tool workspaces, browser data, and other hidden storage hogs missed by generic cleaners.

This is a **disk governance skill** designed for AI coding assistants (such as **Claude Code, Codex, and Antigravity**).

---

## 🌟 Key Features

* **AI-Native Governance**: No CLI commands to memorize. Just ask your AI: *"Audit my C drive and find storage hogs"*.
* **Developer-Friendly**: Specifically detects npm, bun, Python uv caches, browser engines, AI recording folders, WSL virtual disks (`.vhdx`), and Docker images.
* **Safety First**: Uses 5 risk-level categorizations (`auto_clear`, `confirm_then_clear`, `project_work_clean`, `suggest_only`, `never_touch`). It NEVER deletes blindly; a full report is generated first.
* **Closing Snapshot**: Generates an audit report showing before/after disk spaces and details of what was deleted, skipped, or failed.
* **TreeSize Integration**: Speeds up auditing by reading exported CSV reports from TreeSize.

---

## 🚀 Quick Start

### 1. Clone the repository
Clone this project into your local machine:
```powershell
git clone https://github.com/swei99386-alt/windows-c-disk-cleaner.git
cd windows-c-disk-cleaner
```

### 2. Run the Auto-Installer (Recommended)
Run the PowerShell setup script to automatically replace the config username placeholder with your actual Windows username and link this skill to your AI assistant(s):
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```
*Note: This script automatically detects and links to **Claude Code, Codex, and Antigravity** skills directories. If it fails due to Administrator/Developer mode restrictions, it will safely copy the files instead.*

### 3. Start the Conversation
Once installed, open your AI coding assistant (like Claude Code) and ask:
```text
Check what is taking space on C:
```
or:
```text
Find duplicate installer packages in my Downloads directory
```
The AI assistant will automatically execute the scripts behind the scenes and present you with a clear report.

---

## 🛠 Manual Command Line Execution (Optional)

If you prefer running scripts directly without an AI assistant:

```powershell
# Scan only, no deletion (Safe Audit)
powershell -ExecutionPolicy Bypass -File scripts\audit_windows_disk.ps1

# Hunt duplicate downloads/installers
powershell -ExecutionPolicy Bypass -File scripts\find_duplicate_downloads.ps1

# Clean whitelisted low-risk caches (requires -Execute and confirmation)
powershell -ExecutionPolicy Bypass -File scripts\cleanup_low_risk.ps1 -Execute

# Write a closing report detailing space changes
powershell -ExecutionPolicy Bypass -File scripts\write_closing_report.ps1
```

---

## 🛡 Security Boundaries

1. **Default Report-Only**: No deletion occurs unless `-Execute` is explicitly specified.
2. **System Folders Guarded**: `C:\Windows`, `Program Files`, and system configurations are strictly read-only.
3. **Official Cleanups Only**: Windows updates (`SoftwareDistribution`, `$WINDOWS.~BT`) are left to official OS tools.
4. **User Privacy**: Personal documents, WeChat files, and Desktop contents are only summarized, never deleted automatically.

---

## 📂 Repository Structure

```
windows-c-disk-cleaner/
├── SKILL.md                        # Skill definition for AI assistants
├── config/
│   └── auto-clean-policy.json      # Cleaning configuration policy
├── scripts/
│   ├── audit_windows_disk.ps1      # Main disk scanner
│   ├── cleanup_low_risk.ps1        # Cache cleaner (npm, bun, etc.)
│   ├── cleanup_confirmed_safe.ps1  # User-approved cleanup script
│   ├── find_duplicate_downloads.ps1 # Duplicate/Large installer hunter
│   ├── run_disk_governor.ps1       # Standard cross-agent wrapper (Recommended)
│   ├── run_from_treesize.ps1       # TreeSize scanning mode wrapper
│   ├── write_closing_report.ps1    # Before/After comparison report generator
│   ├── start_treesize_scan.ps1     # Opens TreeSize to scan C:
│   └── read_treesize_input.ps1     # Parses TreeSize output CSV
├── references/
│   ├── hotspots.md                 # Typical large directories breakdown
│   └── claude-code.md              # Claude Code integration instructions
└── agents/
    └── openai.yaml                 # OpenAI/Codex agent compatibility config
```

## 📄 License

MIT
