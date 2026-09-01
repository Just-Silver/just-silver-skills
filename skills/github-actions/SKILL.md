---
name: github-actions
description: Use when writing, creating, or modifying GitHub Actions workflow files (.github/workflows/*.yml), choosing trigger events (push, pull_request, schedule, workflow_dispatch), using expressions/contexts in workflows, or unsure about workflow syntax — before writing or editing any GitHub Actions workflow YAML. Never invent workflow syntax from memory; consult the official references here first.
---

# GitHub Actions 工作流编写

## Overview

编写 GitHub Actions workflow（`.github/workflows/*.yml`）时的**权威参考**。所有语法、事件、表达式、上下文均**必须**以官方文档为准，禁止凭记忆臆造。

## 前置步骤（硬性）

编写或修改任何 workflow 前，**必须**先读取对应参考文件：

1. **`references/workflow-syntax.md`** — 顶层键、`on`、`jobs`、`steps`、`permissions`、matrix、job outputs 完整语法
2. **`references/events.md`** — 触发事件选型、安全注意（`pull_request_target` 风险）、fork PR 限制
3. **`references/expressions.md`** — 表达式字面量、运算符、函数、状态检查函数
4. **`references/contexts.md`** — 上下文（`github` / `secrets` / `needs` / `matrix` / `steps` 等）与可用性限制

按需读取；**先本地优先**——references 文件已提炼官方要点，优先从中取信息，不要一上来就抓网页。确实不确定时再回查各 references 文件**顶部标注的官方源链接**（权威完整版，与本技能冲突时以官方原文为准），不得凭记忆补全语法。

## When to Use

- 需要新建 workflow 文件（`.github/workflows/*.yml` / `.yaml`）
- 修改现有 workflow 的触发条件、job、step、权限
- 选择触发事件（push vs pull_request vs workflow_dispatch vs schedule）
- 编写或修改表达式 `${{ }}`、`if` 条件、matrix 策略
- 使用上下文（`github.ref` / `needs.*` / `secrets.*` 等）但不确定正确写法
- 设置 `permissions` 最小权限

**不适用**：不是 GitHub Actions 的 CI（如 GitLab CI / Jenkins），或不需要写 workflow 文件（纯操作 `gh run` 查看状态）。

## Quick Reference

| 需求 | 看哪个文件 |
|------|-----------|
| 文件放哪、顶层键有哪些 | `references/workflow-syntax.md` |
| 触发事件怎么选、安全注意 | `references/events.md` |
| `if` / `${{ }}` / 函数 | `references/expressions.md` |
| `github.*` / `needs.*` / 可用性限制 | `references/contexts.md` |
| 语法校验 | `actionlint`（见下） |

## 校验方法

写完后用 `actionlint` 校验语法（若已安装）：

```bash
actionlint .github/workflows/*.yml
```

未安装时不强行安装，可人工对照 references 检查；最终以 GitHub Actions 实际运行结果为准。

## Common Mistakes

- **凭记忆写语法**（如 `on` 结构、`steps` 键名）→ 一律先读 references 对应文件
- **`pull_request_target` 滥用** → 会授予 fork PR 写权限，除非确需基仓 secrets 否则用 `pull_request`
- **忘记 `permissions` 最小化** → 指定任一权限后未指定的全为 `none`，明确声明需要的
- **tag 触发的 workflow 里 `git push`** → checkout 处于 detached HEAD，必须 `git push origin HEAD:main`
- **fork PR 用 secrets** → fork PR 中除 `GITHUB_TOKEN` 外 secrets 不可用
- **`if` 里字符串 vs 布尔** → `${{ }}` 求值为字符串时注意类型；数字/布尔比较用 `fromJSON()`
- **contexts 用错位置** → 某些上下文在特定键不可用（如 `secrets` 不能用于 `if`），见 contexts.md 可用性表
