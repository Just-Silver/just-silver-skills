---
name: github-actions
description: Use when writing, creating, or modifying GitHub Actions or Gitea Actions workflow files (.github/workflows/*.yml or .gitea/workflows/*.yml), choosing trigger events (push, pull_request, schedule, workflow_dispatch), using expressions/contexts in workflows, or unsure about Actions workflow syntax on either platform — before writing or editing any workflow YAML on GitHub or Gitea.
---

# GitHub / Gitea Actions 工作流编写

## Overview

编写 GitHub Actions 或 Gitea Actions workflow 时的**权威参考**。两平台语法约 95% 通用（Gitea Actions 官方设计目标即兼容 GitHub Actions）。所有语法、事件、表达式、上下文均**必须**以对应平台官方文档为准，禁止凭记忆臆造。

## 前置步骤（硬性）

**0. 第一步：确认目标平台** —— GitHub 还是 Gitea？

- **GitHub** → 读下方 1-4 号 GitHub references
- **Gitea** → 读下方 1-4 号 GitHub references（共同语法）+ **`references/gitea-differences.md`（必读）**。语法策略见该文件"版本策略"小节：**默认按"当前默认版本"（1.27）编写，无需访问官方文档**；实例升级后由维护者更新该文件的默认版本标记；仅当用户明确要求高版本特性（如 1.28 表达式函数）且用户/维护者确认版本后，才按官方文档核验

1. **`references/workflow-syntax.md`** — 顶层键、`on`、`jobs`、`steps`、`permissions`、matrix、job outputs 完整语法
2. **`references/events.md`** — 触发事件选型、安全注意（`pull_request_target` 风险）、fork PR 限制
3. **`references/expressions.md`** — 表达式字面量、运算符、函数、状态检查函数
4. **`references/contexts.md`** — 上下文（`github` / `secrets` / `needs` / `matrix` / `steps` 等）与可用性限制
5. **`references/gitea-differences.md`**（仅 Gitea 目标）— 目录 / 事件 / 表达式 / permissions / token / 版本差异清单

按需读取；**GitHub 目标：本地优先**——references 文件已提炼官方要点，优先从中取信息，不要一上来就抓网页；**Gitea 目标：默认信任本地文件**——按 gitea-differences.md"版本策略"写当前默认版本（1.27）语法，不访问官方文档；仅当用户明确要求高版本特性且用户/维护者确认版本后回查官方文档。确实不确定时回查各 references 文件**顶部标注的官方源链接**（权威完整版，与本技能冲突时以官方原文为准），不得凭记忆补全语法。

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

写完后用 `actionlint` 校验语法。**本技能内置校验器**：`scripts/actionlint.exe`（Windows amd64，v1.7.12，官方 release 二进制，已实测）。支持**任意文件数量**——单文件、多文件、glob、stdin 均可：

```bash
# 内置校验器（相对技能目录；Windows 平台）
scripts/actionlint.exe .github/workflows/ci.yml          # 单文件
scripts/actionlint.exe .github/workflows/*.yml           # glob
scripts/actionlint.exe .gitea/workflows/ci.yaml          # Gitea（.gitea/ 不会被自动发现，必须显式路径）
scripts/actionlint.exe                                   # 无参数：自动发现 .github/workflows/
cat .gitea/workflows/ci.yml | scripts/actionlint.exe -   # stdin 单文件
```

常用选项：

- `-ignore '正则'`：按错误消息正则过滤（可重复；RE2 语法）。Gitea `${{ gitea.* }}` 误报实测用法：`-ignore 'undefined variable "gitea"'`
- `-color` / `-no-color`：颜色输出
- `-shellcheck=` / `-pyflakes=`：空串禁用外部检查器（更快）
- 退出码：`0` 无问题 / `1` 发现问题 / `2` 无效参数 / `3` 致命错误
- Gitea 额外注意（实测验证）：`${{ gitea.* }}` 报 `undefined variable "gitea"`；**改用 `github.*` 别名（官方确认功能等同）即可直接通过**，或用上方 `-ignore`；详见 gitea-differences.md

其他平台 / 其他机器：从官方 release 下载对应资产（https://github.com/rhysd/actionlint/releases/latest ，解压取 `actionlint` / `actionlint.exe`），或官方 Docker 镜像（`docker run --rm -v $(pwd):/repo --workdir /repo rhysd/actionlint:latest -color`），或在线 playground（https://rhysd.github.io/actionlint/ ，浏览器 WASM 免安装）。最终以实际运行结果为准。

### 更新内置校验器（保证版本不落后）

- **使用即检查（懒更新）**：校验前先跑 `scripts/update-actionlint.ps1`——查询上游最新版，有新版自动下载替换（幂等：版本相同跳过；`-Force` 强制重下；`-Platform <资产名>` 指定平台；优先用 gh CLI 查 API，失败回退匿名并能降级继续用现有二进制）
- **CI 自动轮询**：仓库 `.github/workflows/update-actionlint.yml` 每周一 03:00 UTC 自动比对并提交更新（`workflow_dispatch` 手动兜底）
- 版本事实源：`scripts/actionlint.version`（脚本与 CI 都读它；升级二进制后需同步更新该文件）

## Common Mistakes

- **凭记忆写语法**（如 `on` 结构、`steps` 键名）→ 一律先读 references 对应文件
- **Gitea 目标却只查 GitHub references** → 必须读 gitea-differences.md；默认按"版本策略"写当前默认版本（1.27）语法（无需访问官方文档），不要臆造高版本特性
- **把 GitHub 专属写法套到 Gitea** → `jobs.*.environment` 被忽略、复杂 `runs-on`（`{group:, labels:}` 形式，Gitea 各版本均不支持；1.28+ 支持的是表达式形式）不存在、GitHub 专属 permissions scope（`checks`/`statuses` 等）不存在；token 是 `GITEA_TOKEN` 不是 `GITHUB_TOKEN`
- **Gitea 1.27 用表达式函数**（`startsWith` / `contains` / `success()` 等）→ 默认（1.27）一律不用表达式函数（官方文档仅支持 `always()`）；分支/tag 判断用事件过滤（`tags: ['v*']`）与 `==` 运算符；仅用户/维护者确认实例为 1.28+ 且要求时才启用标准函数
- **`pull_request_target` 滥用** → 会授予 fork PR 写权限，除非确需基仓 secrets 否则用 `pull_request`
- **忘记 `permissions` 最小化** → 指定任一权限后未指定的全为 `none`，明确声明需要的
- **tag 触发的 workflow 里 `git push`** → checkout 处于 detached HEAD，必须 `git push origin HEAD:main`
- **fork PR 用 secrets** → fork PR 中除内置 token 外 secrets 不可用
- **`if` 里字符串 vs 布尔** → `${{ }}` 求值为字符串时注意类型；数字/布尔比较用 `fromJSON()`
- **contexts 用错位置** → 某些上下文在特定键不可用（如 `secrets` 不能用于 `if`），见 contexts.md 可用性表
- **用 WebFetch 直接抓 `api.github.com` 查 action 版本** → 必 403（GitHub API 强制 User-Agent + 匿名限流 60 次/时/IP）；用 `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name`（认证 5000 次/时），详见 workflow-syntax.md 常用 action 章节