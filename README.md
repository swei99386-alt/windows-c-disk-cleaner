[English](./README_EN.md) | 简体中文

# Windows C Disk Cleaner

你的 C 盘或 E 盘快满了，但又不敢乱删？这个 Skill 让 AI 先查清楚，再直接告诉你：**哪些该删、哪些该留、哪些该搬走。**

它的判断标准很简单：

> 一个文件丢了以后，重新弄回来的成本很低，就不配长期占硬盘空间。

所以，公开安装包、未完成下载、已核验的重复文件，应该明确建议删除；唯一资料、正在运行的软件环境、WSL/Docker 等，应该明确保护。

## 你能得到什么

- 一张“明确建议删除清单”：路径、容量、为什么能删、删后会怎样。
- 安装包不再被假装成“高风险”：需要时从官网重新下载即可。
- 重复文件先用 SHA-256 证明相同，再留一删余。
- 修复备份只有在现用版本正常时才建议删；真正运行中的环境不碰。
- 删除前复核，删除后给出 C/E 盘可用空间前后对比。

## 适合谁

**普通 Windows 用户**：你只需要把下面一句话交给 Claude Code、Codex 或其他能访问本机文件的 AI Agent。

**会用 AI 编程工具的人**：可直接安装这个 Skill，让 Agent 在遇到“C 盘满了”“找重复安装包”“这个大文件能删吗”时按同一套规则工作。

## 三步上手

1. 先让 Agent 只扫描，不删除。
2. 看它给的“明确建议删除清单”。
3. 你确认精确路径后，再让它执行并报告前后空间。

可直接复制：

```text
帮我按“恢复成本低于占用成本就删除”的原则检查 C 盘和 E 盘。先只扫描，给我一张明确建议删除清单：每项写路径、容量、为什么能删、删后影响；不要删除任何文件。
```

更多可复制提示词见 [提示词库](./docs/copyable-prompts.md)。

## 一个真实案例

在一次脱敏的真实清理中，Skill 先核验、再删除了公开安装包和 SHA-256 完全相同的副本，累计释放 **12.49 GB**；WSL、Docker、Claude 运行环境、唯一资料和当前 Windows 桌面均未作为清理目标。[查看案例与规则](./docs/real-cleanup-case.md)

这不是“保证每个人都能释放 12.49 GB”，而是说明它怎样做决定：先证明可恢复或有副本，再果断删。

## 给 Agent 安装

用 Skills CLI 安装到 Codex 和 Claude Code：

```powershell
npx skills add swei99386-alt/windows-c-disk-cleaner -g -a codex -a claude-code
```

先查看仓库能提供什么：

```powershell
npx skills add swei99386-alt/windows-c-disk-cleaner --list
```

也可以克隆后检查并安装：

```powershell
git clone https://github.com/swei99386-alt/windows-c-disk-cleaner.git
cd windows-c-disk-cleaner
powershell -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## 它不会做什么

- 不会因为“看不懂”就把普通安装包全塞回给你判断。
- 不会手删 `System32`、Windows 核心文件、WSL/Docker 虚拟磁盘、已安装软件目录或聊天软件数据。
- 不会把“名字像桌面”的迁移目录误当成当前 Windows 桌面；会先查当前真实路径。
- 不会在没有精确清单和当前线程确认的情况下删除个人目录内容。

## 运行方式

```powershell
# 只盘点
pwsh -NoProfile -File .\scripts\run_disk_governor.ps1 -Mode report-only -EmitJson

# 查找下载目录中的重复文件和大文件
pwsh -NoProfile -File .\scripts\find_duplicate_downloads.ps1 -EmitJson

# 仅执行严格白名单缓存清理
pwsh -NoProfile -File .\scripts\run_disk_governor.ps1 -Mode safe-clean -Execute
```

## 面向 Agent 的判断规则

| 情况 | 默认建议 |
|---|---|
| 可重新下载的 EXE/MSI/APK、未完成下载 | 建议删除 |
| SHA-256 完全相同的文件 | 留一份，删除其余 |
| 已验证的修复备份 | 现用版本正常时建议删除 |
| 唯一照片、视频、文档、项目源码 | 保留或迁移 |
| WSL、Docker、Claude/Codex 运行环境 | 保留或走软件官方流程 |

## 验证与贡献

仓库使用 PowerShell 7 验证。运行：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Repository.ps1
```

请阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。不要扩大危险自动删除范围，也不要提交私人路径或真实用户数据。

## License

MIT
