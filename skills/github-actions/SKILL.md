---
name: github-actions
description: Use when writing, creating, or modifying GitHub Actions or Gitea Actions workflow files (.github/workflows/*.yml or .gitea/workflows/*.yml), choosing trigger events (push, pull_request, schedule, workflow_dispatch), using expressions/contexts in workflows, or unsure about Actions workflow syntax on either platform — before writing or editing any workflow YAML. Never invent workflow syntax from memory; consult the official references here first.
---

# GitHub / Gitea Actions 工作流编写

## Overview

编写 GitHub Actions 或 Gitea Actions workflow 时的**权威参考**。两平台语法约 95% 通用（Gitea Actions 官方设计目标即兼容 GitHub Actions）。所有语法、事件、表达式、上下文均**必须**以对应平台官方文档为准，禁止凭记忆臆造。

## 前置步骤（硬性）

**0. 第一步：确认目标平台** —— GitHub 还是 Gitea？

- **GitHub** → 读下方 1-4 号 GitHub references
- **Gitea** → 读下方 1-4 号 GitHub references（共同语法）+ **`references/gitea-differences.md`（必读）** + **必须访问 https://docs.gitea.com/usage/actions/ 核验当前版本差异**（Gitea 语法随版本演进，如表达式函数 1.27 仅 `always()`、1.28 起支持标准函数；本地文件仅是摘要）

1. **`references/workflow-syntax.md`** — 顶层键、`on`、`jobs`、`steps`、`permissions`、matrix、job outputs 完整语法
2. **`references/events.md`** — 触发事件选型、安全注意（`pull_request_target` 风险）、fork PR 限制
3. **`references/expressions.md`** — 表达式字面量、运算符、函数、状态检查函数
4. **`references/contexts.md`** — 上下文（`github` / `secrets` / `needs` / `matrix` / `steps` 等）与可用性限制
5. **`references/gitea-differences.md`**（仅 Gitea 目标）— 目录 / 事件 / 表达式 / permissions / token / 版本差异清单

按需读取；**GitHub 目标：先本地优先**——references 文件已提炼官方要点，优先从中取信息，不要一上来就抓网页；**Gitea 目标：本地文件仅作起点，必须回查 Gitea 官方文档**（版本差异决定可用语法）。确实不确定时回查各 references 文件**顶部标注的官方源链接**（权威完整版，与本技能冲突时以官方原文为准），不得凭记忆补全语法。

## When to Use

- 新建或修改 GitHub workflow（`.github/workflows/*.yml` / `.yaml`）
- 新建或修改 Gitea workflow（`.gitea/workflows/*.yml` / `.yaml`）
- 选择触发事件（push vs pull_request vs workflow_dispatch vs schedule）
- 编写或修改表达式 `${{ }}`、`if` 条件、matrix 策略
- 使用上下文（`github.ref` / `gitea.*` / `needs.*` / `secrets.*` 等）但不确定正确写法
- 设置 `permissions` 最小权限（注意两平台 scope 差异）
- 在两个平台间迁移 workflow（`Pull Request` 迁移用 gitea-differences.md 的检查清单）

**不适用**：其他 CI 系统（GitLab CI / Jenkins 等）的流水线语法；纯操作 run 状态（`gh run` 查看）不需要写 workflow 文件。

## Quick Reference

| 需求 | 看哪个文件 |
|------|-----------|
| 文件放哪、顶层键有哪些 | `references/workflow-syntax.md` |
| 触发事件怎么选、安全注意 | `references/events.md` |
| `if` / `${{ }}` / 函数 | `references/expressions.md` |
| `github.*` / `needs.*` / 可用性限制 | `references/contexts.md` |
| **Gitea 平台差异（目录/表达式/权限/token/版本）** | **`references/gitea-differences.md`** |
| 语法校验 | `actionlint`（见下） |

## 校验方法

写完后用 `actionlint` 校验语法（官方仓库：https://github.com/rhysd/actionlint ，usage 文档：https://github.com/rhysd/actionlint/blob/main/docs/usage.md）。**支持任意文件数量**——单文件、多文件、glob、stdin 均可：

```bash
# 单文件（显式传路径）
actionlint .github/workflows/ci.yml
# 多文件 / glob
actionlint .github/workflows/*.yml
# Gitea workflow（.gitea/workflows/ 不会被自动发现，必须显式传路径）
actionlint .gitea/workflows/*.yml
# 无参数：自动发现当前仓库 .github/workflows/ 下全部工作流
actionlint
# stdin：从管道读取单个工作流
cat .gitea/workflows/ci.yml | actionlint -
```

常用选项：

- `-ignore '正则'`：按错误消息正则过滤（可重复；RE2 语法），如需放行 Gitea act_runner 的 action 版本误报
- `-color` / `-no-color`：颜色输出
- `-shellcheck=` / `-pyflakes=`：空串禁用外部检查器（更快）
- 退出码：`0` 无问题 / `1` 发现问题 / `2` 无效参数 / `3` 致命错误
- Gitea 额外注意：`${{ gitea.* }}` 会报 `undefined variable`（用 `github.*` 或 `-ignore`），详见 gitea-differences.md

未安装时**不强行安装**：可人工对照 references 检查，或用官方 Docker 镜像（`docker run --rm -v $(pwd):/repo --workdir /repo rhysd/actionlint:latest -color`）或在线 playground（https://rhysd.github.io/actionlint/，浏览器跑 WASM 免安装）。最终以实际运行结果为准。

## Common Mistakes

- **凭记忆写语法**（如 `on` 结构、`steps` 键名）→ 一律先读 references 对应文件
- **Gitea 目标却只查 GitHub references** → Gitea 语法随版本演进，必须读 gitea-differences.md + 访问 Gitea 官方文档核验
- **把 GitHub 专属写法套到 Gitea** → `jobs.*.environment` 被忽略、复杂 `runs-on`（`{group:, labels:}` 形式，Gitea 各版本均不支持；1.28+ 支持的是表达式形式）不存在、GitHub 专属 permissions scope（`checks`/`statuses` 等）不存在；token 是 `GITEA_TOKEN` 不是 `GITHUB_TOKEN`
- **Gitea 1.27 用表达式函数**（`startsWith` / `contains` / `success()` 等）→ 1.27 官方文档仅支持 `always()`；分支/tag 判断改用事件过滤（`tags: ['v*']`）与 `==` 运算符；1.28+ 以官方文档为准
- **`pull_request_target` 滥用** → 会授予 fork PR 写权限，除非确需基仓 secrets 否则用 `pull_request`
- **忘记 `permissions` 最小化** → 指定任一权限后未指定的全为 `none`，明确声明需要的
- **tag 触发的 workflow 里 `git push`** → checkout 处于 detached HEAD，必须 `git push origin HEAD:main`
- **fork PR 用 secrets** → fork PR 中除内置 token 外 secrets 不可用
- **`if` 里字符串 vs 布尔** → `${{ }}` 求值为字符串时注意类型；数字/布尔比较用 `fromJSON()`
- **contexts 用错位置** → 某些上下文在特定键不可用（如 `secrets` 不能用于 `if`），见 contexts.md 可用性表