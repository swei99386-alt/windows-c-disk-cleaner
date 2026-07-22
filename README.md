[English](./README_EN.md) | 简体中文

# Windows C Disk Cleaner

AI 辅助 Windows 磁盘审计与清理 Skill。它不把“不确定”一律推给用户：用“删除后的恢复成本，是否低于持续占用空间的成本”给出明确的删、留、搬建议；执行删除前仍需要用户确认精确清单。

## 安全警告

它会默认建议删除可重新下载的公开安装包、未完成下载，以及已用 SHA-256 证明完全重复的副本；但不会手删唯一资料、正在使用的运行环境、WSL/Docker 虚拟磁盘、系统目录或已安装软件。删除必须先展示精确路径与删后影响，再由用户确认；永久删除不承诺可恢复。

## 核心能力

- 自动识别本机固定磁盘，系统盘优先
- 用恢复成本而非“极端保守”判断大文件、开发者缓存和备份
- 低风险缓存清理（仅在用户确认后）
- 公开安装包默认删除建议；SHA-256 重复文件保留一份、删除其余
- 核验修复备份、迁移副本与当前实际桌面/项目路径的关系
- 输出可供 Claude Code、Codex 和其他 Agent 复用的 JSON 报告

## 快速安装

推荐先克隆、检查代码，再安装：

```powershell
git clone https://github.com/swei99386-alt/windows-c-disk-cleaner.git
cd windows-c-disk-cleaner
powershell -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

在线安装（脚本会下载并检查 ZIP，不使用不透明的 `irm | iex`）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest 'https://raw.githubusercontent.com/swei99386-alt/windows-c-disk-cleaner/main/install-online.ps1' -OutFile '$env:TEMP\windows-c-disk-cleaner-install.ps1'; & '$env:TEMP\windows-c-disk-cleaner-install.ps1'"
```

支持 `-Target All|ClaudeCode|Codex|Antigravity`、`-InstallMode Auto|Junction|Copy`、`-Force` 和 `-WhatIf`。冲突目录默认保留并报告，`-Force` 也会先改名备份。

## 支持的 AI 助手

Claude Code、Codex、Antigravity。安装器会逐项显示 `installed`、`already_installed`、`conflict`、`failed` 等结果。

## 使用示例

```text
帮我检查一下 C 盘为什么快满了，只报告，不要删除。
扫描本机所有固定磁盘，列出超过 1GB 的目录。
只清理严格白名单里的低风险缓存，执行前先告诉我预计能释放多少。
检查下载目录：普通公开安装包直接列为建议删除，个人资料只在确认重复后才删。
检查这个 App.pre-repair 目录是不是已不需要的修复备份；如果现用 App 正常，就给出明确建议。
```

## 示例输出

见 [docs/example-output.md](./docs/example-output.md)。这是示例格式，不代表固定清理效果。

## 安全分级

对外使用六类：默认建议删除、哈希重复留一删余、已验证备份可删、建议迁移或归档、应通过 Windows 或应用内部处理、禁止手动处理。

## 手动运行命令

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_disk_governor.ps1 -Mode report-only -EmitJson
powershell -ExecutionPolicy Bypass -File .\scripts\find_duplicate_downloads.ps1 -EmitJson
pwsh -NoProfile -File .\scripts\run_disk_governor.ps1 -Mode safe-clean -Execute
```

## 已验证环境

- CI verified：Windows GitHub Actions 的 PowerShell 7 Parser、JSON、仓库规则和安装器 WhatIf。
- Manually verified：本仓库测试脚本和安装器 WhatIf 已在当前 Windows 环境执行。
- Not yet verified：未在 Claude Code、Codex、Antigravity 真实客户端逐一安装验证。

本项目当前按 PowerShell 7 验证；Windows PowerShell 5.1 不在支持承诺内。

## 当前限制

没有真实清理数据，因此不声称释放了任何空间；真实运行截图待人工补充。Docker、WSL 与应用数据迁移只发现和报告，不能自动删除或自动搬家。浏览器运行时不扫描其 Profile 树。

## 文件结构

`SKILL.md`、`config/auto-clean-policy.json`、`scripts/`、`references/`、`agents/openai.yaml`、`tests/`、`.github/workflows/ci.yml`。

## 贡献方式

请先阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)，尤其不要扩大危险自动删除范围或提交私人路径。

## License

MIT
