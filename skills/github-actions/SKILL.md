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

> 先确认平台：GitHub → 1-4；Gitea → 1-4 + `gitea-differences.md` 必读（默认按 1.27，不访问官方文档；需 1.28+ 再向用户确认）。

## 校验

`scripts/actionlint.exe`（Windows amd64, v1.7.12）支持单/多文件与 stdin：`scripts/actionlint.exe .github/workflows/ci.yml`；Gitea 须显式路径。pwsh 下 `*.yml` 不自动展开，逐个列出。误报 `gitea` 用 `-ignore 'undefined variable "gitea"'`。版本源 `scripts/actionlint.version`，先跑 `scripts/update-actionlint.ps1` 单次保鲜。

## Common Mistakes

- 凭记忆写 `on` / `permissions` → 必读对应 reference
- Gitea 套用 `environment` / `{group:,labels:}` / 专属 scope / `GITHUB_TOKEN`
- Gitea 1.27 用函数（仅 `always()`）→ 用事件过滤与 `==` 替代
- `secrets` 误用于 `if`、`pull_request_target` 滥用、tag 回推忘 `HEAD:main`
- 硬编码 `http://server:3500` / 固定 `owner/repo` → 用 `${{ github.server_url }}/${{ github.repository }}/${{ github.ref_name }}` 动态拼接（`gitea-differences.md` Release/回推通用模板，push 需去协议头）
