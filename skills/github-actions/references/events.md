# 触发事件选型（GitHub Actions）

> 官方源：https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
> 本文件为提炼要点，完整事件清单与活动类型以官方页为准。

## 常用事件速查

| 事件 | 用途 | 关键活动类型 / 注意 |
|------|------|---------------------|
| `push` | 推送到分支或 tag | `branches` / `tags` / `paths` 过滤；tag 推送可用 `tags: ['v*']` |
| `pull_request` | PR 活动 | 默认 `opened` / `synchronize` / `reopened`；合并后 `closed` + `github.event.pull_request.merged` 判断 |
| `pull_request_target` | PR 且需基仓 secrets/权限 | **安全风险高**：来自 fork 的 PR 也会用基仓的写权限 token，慎用，见安全章节 |
| `workflow_dispatch` | 手动触发 | 支持 `inputs`；仅默认分支上的文件触发 |
| `schedule` | 定时 | POSIX cron，最短 5 分钟 |
| `workflow_call` | 可复用工作流被调用 | 定义 `inputs`/`outputs`/`secrets` |
| `workflow_run` | 另一 workflow 完成后触发 | `workflows: ["Build"]` + `types: [completed]` |
| `release` | 发布 Release 时 | `types: [published, created]` |
| `issues` / `issue_comment` | Issue 管理 | `opened` / `closed` / `labeled` 等 |
| `create` / `delete` | 创建/删除 branch 或 tag | tag 触发的发布常用 `push.tags` 而非 `create` |
| `merge_group` | 合并队列 | `types: [checks_requested]`，配 PR 检查必加 |

## 选择指引（决策流程）

**目标是什么？**

1. **代码提交后自动检查/构建/测试** → `push`（配 `branches`/`paths` 过滤）或 `pull_request`
2. **PR 上运行检查** → `pull_request`（在 fork PR 中 secrets 不传，仅 `GITHUB_TOKEN` 只读）
3. **打 tag 自动发版** → `push` + `tags: ['v*']`（比 `release` 事件更简单，天然触发）
4. **手动点按钮跑** → `workflow_dispatch` + `inputs`
5. **定时任务** → `schedule` + cron
6. **供其他 workflow 复用** → `workflow_call`
7. **等别的 workflow 完成后做后续** → `workflow_run`

## 关键安全注意

- **`pull_request_target` 会授予写权限 GITHUB_TOKEN 给 fork 的 PR**——除非绝对必要（如需读 secrets 做审查），否则用 `pull_request`
- fork PR 中：**除 `GITHUB_TOKEN` 外所有 secrets 不传给 runner**；`GITHUB_TOKEN` 在 fork PR 是只读
- 首次贡献者的 PR 需维护者批准后才能运行 workflow
- Dependabot 的 PR 按 fork PR 处理，受同样限制

## 活动类型与过滤

- `on.<event>.types`：只监听特定活动（如 `issues.types: [opened]`）
- `branches` / `paths` / `tags` 过滤器仅对特定事件可用（`push`/`pull_request`/`pull_request_target` 支持 `paths`）
- 多个事件同时满足会触发**多次**运行（如同时 push + 打开带 label 的 issue）
- `paths` 过滤注意：PR 用 three-dot diff（head 相对 base 分支的差异），push 用 two-dot
