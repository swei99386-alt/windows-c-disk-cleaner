# 可复制提示词

以下提示词适用于 Claude Code、Codex 或任何获得本机文件读取权限的 AI Agent。

## 1. 只扫描，不删除

```text
帮我检查 C 盘和 E 盘为什么空间紧张。按“删除后的恢复成本低于持续占用成本，就建议删除”的原则判断。先不要删除任何文件；给我一张明确建议删除清单，每项必须写：精确路径、大小、为什么能删、删后影响、预计释放空间。不要把普通公开安装包一律标成高风险。
```

```text
Audit why C: and E: are low on space. Use this rule: recommend deletion when the real recovery cost is lower than the cost of keeping the file. Do not delete anything yet. Produce an exact manifest with path, size, reason, impact, and estimated reclaimed space. Do not label ordinary public installers as high-risk by default.
```

## 2. 核验重复和备份

```text
检查下载目录、旧备份和迁移目录。安装包、APK、未完成下载默认按可重新下载处理；重复文件必须用 SHA-256 核验后只留一份；修复备份必须确认现用程序正常后才建议删除。特别注意：迁移目录名字像 Desktop 不代表它是当前 Windows 桌面，先查当前真实桌面路径。
```

```text
Inspect Downloads, old backups, and migrated folders. Treat public installers, APKs, and incomplete downloads as re-downloadable. Use SHA-256 before deleting duplicate copies, and recommend deleting a repair backup only after verifying the live app is healthy. A folder named Desktop is not proof that it is the active Windows Desktop; verify the live known-folder path first.
```

## 3. 确认后执行

```text
我确认删除你刚才清单中的精确路径。执行前重新核验候选文件没有变化；只删除清单里的项目。完成后报告 C/E 盘删除前后可用空间，并分四行写：已删、没删、还能删、为什么跳过。
```

```text
I confirm deletion of the exact paths in the manifest you just produced. Re-validate them immediately before execution and delete only listed items. Report C: and E: free space before and after, then provide four lines: deleted, not deleted, still reclaimable, and why anything was skipped.
```
