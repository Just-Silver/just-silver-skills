# Just-Silver Skills

个人自用的 OpenCode 技能集（仅自建技能）。

<!-- AUTO-GENERATED: 技能表格由 scripts\update-readme.ps1 生成，请勿手改 -->

| 技能 | 介绍 | 跳转位置 |
|------|------|----------|
| bootstrapblazor | Use when working with BootstrapBlazor (also called BB, bb, or bootstrapblazor) components and needing their... | [skills/bootstrapblazor/](skills/bootstrapblazor/) |

<!-- /AUTO-GENERATED -->

## 安装

将 `skills/<name>/` 复制到本地技能目录：

- OpenCode（Windows）：`C:\Users\<user>\.config\opencode\skills\`

```powershell
Copy-Item -Recurse skills/bootstrapblazor "$env:USERPROFILE\.config\opencode\skills\"
```

## 维护

- 技能结构：`skills/<name>/SKILL.md`（frontmatter：`name` + `description`）
- 新增/修改技能后：本地跑 `./scripts/update-readme.ps1` 重新生成清单（或由 GitHub Actions 自动生成）
- commit → push（提交信息用中文）

## 许可

MIT