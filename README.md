[English](./README_EN.md) | 简体中文

# Windows C Disk Cleaner

AI 辅助 Windows 磁盘审计与安全清理 Skill。默认只扫描和报告，只有用户明确确认后才执行严格白名单里的低风险缓存清理。

## 安全警告

请先看报告再决定。工具不会自动删除个人文档、下载、桌面文件、WSL、Docker 虚拟磁盘或系统目录；删除后不保证可以恢复。清理必须同时显式传入 `-Execute`，并且迁移/目录联接永远是独立的人工任务，不属于本 Skill 的自动能力。

## 核心能力

- 自动识别本机固定磁盘，系统盘优先
- 解释大文件、开发者缓存、浏览器缓存和 VHDX 的风险
- 低风险缓存清理（仅在用户确认后）
- 重复安装包和大文件报告
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
检查下载目录中的重复安装包，但不要自动删除个人文档。
```

## 示例输出

见 [docs/example-output.md](./docs/example-output.md)。这是示例格式，不代表固定清理效果。

## 安全分级

对外使用五类：可安全清理、用户确认后清理、建议迁移或归档、应通过 Windows 或应用内部处理、禁止手动处理。

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
