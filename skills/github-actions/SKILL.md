---
name: github-actions
description: Use when creating or editing GitHub Actions or Gitea Actions workflow YAML (.github/workflows/*.yml, .gitea/workflows/*.yml), choosing trigger events (push, pull_request, schedule, workflow_dispatch), writing expressions, contexts, permissions, or troubleshooting workflow syntax and CI failures on either platform.
---

# GitHub / Gitea Actions 工作流编写

## Overview

GitHub Actions 与 Gitea Actions 约 95% 语法通用（后者兼容前者）。禁止凭记忆臆造语法——所有键、事件、表达式、上下文以官方文档为准，`references/` 已提炼要点，按需加载。

## When to Use

- 新建/修改 `.github/workflows/*.yml` 或 `.gitea/workflows/*.yml`
- 选触发事件、写 `if` / `${{ }}` / matrix、配 `permissions` / `concurrency`
- 不确定 `github.*` / `secrets` / `needs` / `matrix` 可用性
- 排查 workflow 语法或 CI 失败

**不适用**：GitLab CI / Jenkins 等其他 CI。

## 前置路由（按需加载，不全读）

| 场景 | 读取 |
|------|------|
| 顶层键、`on`、`jobs`、`steps`、`permissions`、matrix/outputs | `references/workflow-syntax.md` |
| 触发事件与 `pull_request_target` 安全 | `references/events.md` |
| `${{ }}`、运算符、函数、状态检查 | `references/expressions.md` |
| `github` / `secrets` / `needs` 等上下文 | `references/contexts.md` |
| **Gitea 目标必读**：目录、token、权限、版本差异 | `references/gitea-differences.md` |
| 质量门禁、CI 优化、部署策略 | `references/ci-cd-practices.md` |
| CD/发版/Release（含 `push.tags` / `releases` API / `cd.yml`） | `references/ci-cd-practices.md` + `references/changelog-conventions.md` 必读（CHANGELOG 是输入，Release 引用它；tag==CHANGELOG==包版本一致性进流水线） |

> 凡文件含 `push.tags`、`releases` API、`CHANGELOG` 或任务含“发版/CD/Release”，必须走此分支；绕过即违规，`gitea-differences.md` 的 `git log` 演示不得覆盖本分支。

> 先确认平台：GitHub → 1-4；Gitea → 1-4 + `gitea-differences.md` 必读（默认按 1.27，不访问官方文档；需 1.28+ 再向用户确认）。

## 校验

`scripts/actionlint.exe`（Windows amd64, v1.7.12）支持单/多文件与 stdin：`scripts/actionlint.exe .github/workflows/ci.yml`；Gitea 须显式路径。pwsh 下 `*.yml` 不自动展开，逐个列出。误报 `gitea` 用 `-ignore 'undefined variable "gitea"'`。版本源 `scripts/actionlint.version`，先跑 `scripts/update-actionlint.ps1` 单次保鲜。

## Common Mistakes

- 凭记忆写 `on` / `permissions` → 必读对应 reference
- Gitea 套用 `environment` / `{group:,labels:}` / 专属 scope / `GITHUB_TOKEN`
- Gitea 1.27 用函数（仅 `always()`）→ 用事件过滤与 `==` 替代
- `secrets` 误用于 `if`、`pull_request_target` 滥用、tag 回推忘 `HEAD:main`
- 硬编码 `http://server:3500` / 固定 `owner/repo` → 用 `${{ github.server_url }}/${{ github.repository }}/${{ github.ref_name }}` 动态拼接（`gitea-differences.md` Release/回推通用模板，push 需去协议头）
- 发版流水线未校验 `tag == CHANGELOG == package.json` 或 Release body 非来自 `CHANGELOG.md`（见 `changelog-conventions.md` 一致性卡点）→ CD 发版必须从 `CHANGELOG.md` 该版本小节提取 body，`git log` 堆砌属违规
- 带 `git push` 回推的 workflow 用 `cancel-in-progress: true` 或各用不同 `group` 名 → 取消丢提交 / 照样 push 冲突；须多个 workflow 共用同一 `group` 名 + `cancel-in-progress: false` 排队（见 `ci-cd-practices.md`「多 workflow 回推排队」）

## 发版（CD）落地清单

写完/检查含 `push.tags` / `releases` / `cd.yml` 的 workflow 后逐项过：

- [ ] `CHANGELOG.md` 存在且顶部有 `## [Unreleased]`，发版前已整理为 `## [x.y.z] - YYYY-MM-DD`（见 `references/changelog-conventions.md`）
- [ ] CD 含 `tag == CHANGELOG == package.json` 一致性校验，不一致即 fail
- [ ] Release body 来自 `CHANGELOG.md` 该版本小节截段，非 `git log` 堆砌（模板见 `references/gitea-differences.md`「Gitea Release 发布」）
