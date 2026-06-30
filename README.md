# Windows C盘清理助手

> 通过和 AI 对话，帮你智能清理 Windows 电脑的 C 盘和整个硬盘——包括那些普通清理软件扫不到的 AI 工具缓存、开发者缓存、以及隐私敏感区域。

## 这是什么

这是一套为 AI 编程助手（Claude Code、Codex、Antigravity 等）设计的**磁盘治理技能（Skill）**。

普通清理软件只会清垃圾桶和临时文件。这套工具的不同之处在于：

- **它会和 AI 对话**——你不需要记任何命令，直接说"帮我看看 C 盘哪里大"，AI 就会扫描并用大白话给你解释
- **它懂开发者环境**——能识别 npm 缓存、Python uv 缓存、浏览器内核、AI 工具数据、WSL 虚拟盘等现代工具的数据
- **它先报告、再动手**——绝不自动删东西，每一步都告诉你"这是什么、删了有什么影响、能不能恢复"，你确认了才清
- **它有安全分级**——把所有大文件分成五类：可直接清 / 确认后清 / 建议搬到别的盘 / 只能软件内处理 / 绝对不能碰

## 能帮你做什么

| 功能 | 说明 |
|---|---|
| 全盘扫描 | 扫描 C/D/E 等多个分区，列出大文件排行 |
| 自动清缓存 | 安全清理 npm、bun、浏览器缓存、AI 工具录屏等低风险缓存 |
| 重复包猎手 | 找出下载目录里名字带 `(1)(2)` 的重复安装包 |
| 大文件体检 | 解释每个大文件夹是什么、删了会怎样、能不能搬走 |
| 收尾快照 | 清理完自动写一份前后对比报告，下次接着用 |
| TreeSize 联动 | 支持读取 TreeSize 导出报告，加速扫描 |

## 适合谁用

- 用 **Claude Code、Codex、Antigravity** 等 AI 助手的开发者
- C 盘经常爆红但不知道哪里大的 Windows 用户
- 不想折腾命令行、但想比普通清理软件清得更彻底的用户

## 快速开始

### 1. 安装到你的 AI 助手

把这个仓库克隆到你的 AI 助手技能目录：

```powershell
# Claude Code
git clone https://github.com/swei99386-alt/windows-c-disk-cleaner "$env:USERPROFILE\.claude\skills\windows-c-disk-cleaner"

# Codex
git clone https://github.com/swei99386-alt/windows-c-disk-cleaner "$env:USERPROFILE\.codex\skills\windows-c-disk-cleaner"
```

### 2. 配置你的用户名

打开 `config/auto-clean-policy.json`，把所有 `YOURUSERNAME` 替换成你 Windows 的实际用户名：

```powershell
# 查看你的用户名
$env:USERNAME
```

### 3. 开始对话

在 Claude Code 或 Codex 里直接说：

```
帮我扫一下 C 盘哪里占地方最多
```

或者：

```
找一下我下载目录里有没有重复的安装包
```

AI 会自动调用这套工具，给你一份清晰的中文报告。

## 手动运行脚本

不想通过 AI 对话，也可以直接跑 PowerShell 脚本：

```powershell
# 只扫描、不删（默认安全模式）
powershell -ExecutionPolicy Bypass -File scripts\audit_windows_disk.ps1

# 查找重复下载包
powershell -ExecutionPolicy Bypass -File scripts\find_duplicate_downloads.ps1

# 清理低风险缓存（需要确认）
powershell -ExecutionPolicy Bypass -File scripts\cleanup_low_risk.ps1 -Execute

# 写一份清理前后的收尾快照
powershell -ExecutionPolicy Bypass -File scripts\write_closing_report.ps1
```

## 安全原则

这套工具遵循几条铁律：

1. **默认只看、不删** — 所有脚本不加 `-Execute` 参数就只报告，不动文件
2. **五层风险分级** — 每个路径都有明确的处理分类，不会把"用户确认后才能删"的东西当成"直接清"
3. **系统目录永不碰** — `C:\Windows`、`Program Files`、系统更新文件只会报告，不会手动删除
4. **个人数据归用户决定** — 微信聊天记录、个人文档等只提示大小，不会自动处理

## 文件结构

```
windows-c-disk-cleaner/
├── SKILL.md                        # AI 助手技能说明（触发条件、工作流程）
├── config/
│   └── auto-clean-policy.json      # 清理策略配置（需填入你的用户名）
├── scripts/
│   ├── audit_windows_disk.ps1      # 主扫描脚本
│   ├── cleanup_low_risk.ps1        # 低风险缓存清理
│   ├── cleanup_confirmed_safe.ps1  # 用户确认后的清理
│   ├── find_duplicate_downloads.ps1 # 重复包/大文件猎手
│   ├── run_disk_governor.ps1       # 统一入口（推荐）
│   ├── run_from_treesize.ps1       # TreeSize 联动模式
│   ├── write_closing_report.ps1    # 收尾快照
│   ├── start_treesize_scan.ps1     # 启动 TreeSize
│   └── read_treesize_input.ps1     # 读取 TreeSize 报告
├── references/
│   ├── hotspots.md                 # 常见大文件热点说明
│   └── claude-code.md              # Claude Code 复用指南
└── agents/
    └── openai.yaml                 # Codex/OpenAI 兼容配置
```

## License

MIT
