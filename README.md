## 一键安装/更新

```bash
curl -fsSL https://raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/install-skills.sh | bash
```

Windows 请在 Git Bash（或任意带 bash 的命令窗）中执行；无需先克隆仓库，自动拉取最新版并原子替换全局 `skills/just-silver-skills/`（Windows 下即 `C:\Users\<你>\.config\opencode\skills\just-silver-skills\`），不动他人技能，幂等可重跑。

## 一键卸载

```bash
curl -fsSL https://raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/uninstall-skills.sh | bash
```

删除全局 `skills/just-silver-skills/`，并顺带清理安装/更新异常中断可能残留的临时目录。

<!-- AUTO-GENERATED: 技能表格由 scripts\update-readme.ps1 生成，请勿手改 -->

| 技能 | 介绍 | 跳转位置 |
|------|------|----------|
| bootstrapblazor | Use when working with BootstrapBlazor (also called BB, bb, or bootstrapblazor) components and needing their... | [skills/bootstrapblazor/](skills/bootstrapblazor/) |
| dotnet-development | Use when writing, modifying, or reviewing C# / .NET code in any project type (ASP.NET Core, WPF, WinForms, ... | [skills/dotnet-development/](skills/dotnet-development/) |
| github-actions | Use when creating or editing GitHub Actions or Gitea Actions workflow YAML (.github/workflows/*.yml, .gitea... | [skills/github-actions/](skills/github-actions/) |

<!-- /AUTO-GENERATED -->
