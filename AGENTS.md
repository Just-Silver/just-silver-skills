# AGENTS.md

个人自建的 OpenCode 技能集仓库：`skills/<name>/SKILL.md` 是唯一数据源。
交流用简体中文；git commit 信息用中文。

## 核心：README.md 是自动生成的产物

- README 的技能表格由 `scripts/update-readme.ps1` 从各技能 frontmatter 生成（AUTO-GENERATED 注释块包裹）——**不要手动改表格内容**，会被下次运行覆盖
- 新增/修改技能：只编辑 `skills/<name>/SKILL.md`，然后运行 `./scripts/update-readme.ps1`（或直接 push，CI 自动生成）
- frontmatter 必须含 `name` + `description`；`description` 截断至 110 字符（107 + `...`）并转义 `|`，作为表格"介绍"列
- 脚本幂等：连续运行两次 README 字节不变；缺 AUTO-GENERATED 标记块时脚本报错（首次初始化后全自动）

## CI 工作流（.github/workflows/）

### update-readme.yml

- 触发：push 到 main 且变更匹配 `paths: ['skills/**']`，或手动 workflow_dispatch
- 防循环关键：自动提交只改 `README.md`（不在 `skills/**` 内）→ 不递归触发。**改 workflow 时保留 paths 过滤**
- 上传 `.github/workflows/` 文件：REST API 需 Workflows 权限（tool token 通常没有）→ 一律用 git push

### update-actionlint.yml

- 触发：`schedule` 每周一 03:00 UTC + `workflow_dispatch` 手动兜底（**push 不触发**）
- 职责：轮询 rhysd/actionlint 上游最新版 → 有新版本自动提交 `skills/github-actions/scripts/actionlint.exe` + `actionlint.version`（无更新则跳过）
- 路径注意：脚本在**技能目录** `skills/github-actions/scripts/update-actionlint.ps1`，**不在仓库根 `scripts/`**（后者只有 update-readme.ps1）——两个 workflow 的调用路径不同，别搞混（曾因此踩坑）
- 防循环：自动提交只改 `skills/**` 下校验器文件 → 会触发 update-readme（paths: skills/**）→ 后者只提交 README.md → 终止
- **教训**：新增/修改 schedule 类 workflow 后必须立即 `gh workflow run` 手动冒烟一次，不得等调度窗口（路径 bug 曾潜伏到首次手动触发才暴露）

## 技能内容约束（bootstrapblazor 示例）

- 每个技能必须有 frontmatter（name + description）+ 明确的行为指令（When to Use / 禁止事项）
- bootstrapblazor：禁止臆造组件 API，必须 `bb-llms --help` 验证可用性后用 `get/search/list` 查官方文档；bb-llms 未装时只提示用户手动安装，**不得自行 dotnet tool install、不得臆造**