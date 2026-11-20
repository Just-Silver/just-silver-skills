---
name: github-actions
description: Use when creating or editing GitHub Actions or Gitea Actions workflow YAML (.github/workflows/*.yml, .gitea/workflows/*.yml), publishing releases (including pre-releases), choosing trigger events (push, pull_request, schedule, workflow_dispatch), writing expressions, contexts, permissions, or troubleshooting workflow syntax and CI failures on either platform.
---

# GitHub / Gitea Actions 工作流

## 适用

- 新建/修改 `.github/workflows/*.yml` 或 `.gitea/workflows/*.yml`
- 选触发事件；写 `if` / `${{ }}` / matrix；配 `permissions` / `concurrency`
- 查 `github.*` / `secrets` / `needs` / `matrix` 等上下文
- 排查 workflow 语法或 CI 失败

不适用：GitLab CI、Jenkins 等其他 CI。

## 参考文件

| 内容 | 文件 |
|------|------|
| 顶层键、`on`、`jobs`、`steps`、`permissions`、matrix/outputs | `references/workflow-syntax.md` |
| 触发事件与 `pull_request_target` 安全 | `references/events.md` |
| `${{ }}`、运算符、函数、状态检查 | `references/expressions.md` |
| `github` / `secrets` / `needs` 等上下文 | `references/contexts.md` |
| Gitea 差异 | `references/gitea-differences.md` |
| 质量门禁、CI 优化、部署 | `references/ci-cd-practices.md` |
| CD / CHANGELOG / 版本治理 | `references/changelog-conventions.md` |

Gitea 基线：Server **28.4.0** + Runner **6.0.0**。其他版本查对应官方文档。

## 校验

```bash
scripts/actionlint.exe .github/workflows/ci.yml
scripts/actionlint.exe .gitea/workflows/ci.yml   # Gitea 须显式路径
```

- pwsh 不展开 `*.yml`，逐个列出文件。
- `gitea.*` 报 `undefined variable "gitea"` 时改用 `github.*`，或 `-ignore 'undefined variable "gitea"'`。
- actionlint 1.7.12 不认识 `concurrency.queue`，报 `unexpected key "queue"`；用 `-ignore 'unexpected key "queue"'`，不要删 `queue: max`。
- 版本源 `scripts/actionlint.version`；升级用 `scripts/update-actionlint.ps1`。
- actionlint 通过只证明 GitHub 语法可解析，不证明 Gitea 能解析或运行。

## 常见错误

- 凭记忆写 `on` / `permissions`：查对应 reference。
- Gitea 套用 `jobs.*.environment`、`concurrency.queue`、`type: environment`、`{group:,labels:}`、GitHub 专属 permission scope 或 `GITHUB_TOKEN`。
- job 漏写 `runs-on`（Runner 6.0.0 下直接失败）；job 级 `if:` 使用 `matrix.*`（matrix 尚未展开，应移到 step 级或 `include`/`exclude`）。
- `secrets` 用于 `if`；`pull_request_target` 滥用；tag 回推忘 `HEAD:main`。
- 硬编码实例地址或 `owner/repo`；用 `${{ github.server_url }}` / `${{ github.repository }}` / `${{ github.ref_name }}` 拼接。
- 回推 workflow 误以为 `concurrency` 是可靠队列：GitHub 默认 `queue: single` 会替换 pending；需多个 pending 用 `queue: max`，且仍要 `git pull --rebase` 和失败重试。Gitea 28.4 不支持 `queue`。
- 发版未校验 `tag == CHANGELOG == 包版本`（单一版本源仓），或 Release body 用 `git log` 而不是 `CHANGELOG.md` 对应小节。
- `prerelease` 写死：`x.y.z-<预发布标识>` 为 `true`，`x.y.z` 为 `false`；`draft` 与 `prerelease` 不同。
- 重复创建 Release 不核对旧标记：Gitea 返回 `409`，GitHub 返回 `422 already_exists`；改标记用 `PATCH /repos/{owner}/{repo}/releases/{id}`。
