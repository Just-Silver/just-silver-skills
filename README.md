# Just-Silver Skills

个人自用的 OpenCode 技能集（仅包含自建技能）。

## 技能列表

| 技能 | 说明 |
|------|------|
| bootstrapblazor | BootstrapBlazor（BB/bb）组件参数/事件/公开方法查询，通过 bb-llms CLI 获取官方文档，禁止臆造 API |

## 安装

将 `skills/<name>/` 复制到本地技能目录：

- OpenCode（Windows）：`C:\Users\<user>\.config\opencode\skills\`

```powershell
Copy-Item -Recurse skills/bootstrapblazor "$env:USERPROFILE\.config\opencode\skills\"
```

## 维护

- 技能结构：`skills/<name>/SKILL.md`（frontmatter：`name` + `description`）
- 新增自建技能 → 放入 `skills/` 目录 → commit → push（提交信息用中文）

## 许可

MIT
