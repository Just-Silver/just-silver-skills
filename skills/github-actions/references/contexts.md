# 上下文（Contexts，GitHub Actions）

> 官方源：https://docs.github.com/en/actions/reference/workflows-and-actions/contexts
> 本文件为提炼要点，完整属性清单以官方页为准。

## 可用上下文一览

| 上下文 | 类型 | 说明 |
|--------|------|------|
| `github` | object | 当前 workflow run 与触发事件信息 |
| `env` | object | workflow / job / step 级环境变量 |
| `vars` | object | 仓库 / 组织 / 环境级变量（Settings → Variables 配置） |
| `job` | object | 当前 job 信息（仅步骤执行内可用） |
| `jobs` | object | 可复用工作流中调用方 job 输出 |
| `steps` | object | 当前 job 已运行步骤的信息与输出 |
| `runner` | object | 运行 runner 的信息 |
| `secrets` | object | 可用 secrets（名称与值） |
| `strategy` | object | matrix 执行策略信息 |
| `matrix` | object | 当前 job 的 matrix 属性 |
| `needs` | object | 依赖 job 的输出 |
| `inputs` | object | 可复用或手动触发 workflow 的输入 |

## 访问语法

- 属性：`github.sha`（属性名须字母/`_` 开头，仅含字母数字 `-` `_`）
- 索引：`github['sha']`
- 不存在属性 → 空字符串

## `github` 上下文常用属性

| 属性 | 值 |
|------|-----|
| `github.ref` | 完整 ref：`refs/heads/<branch>` 或 `refs/tags/<tag>` |
| `github.ref_name` | 短名（分支名或 tag 名，如 `v1.0.0`） |
| `github.ref_type` | `branch` 或 `tag` |
| `github.sha` | 触发提交 SHA |
| `github.repository` | `owner/repo`（Gitea 上等同 `gitea.repository`） |
| `github.repository_owner` | owner 用户名 |
| `github.server_url` | 实例根 URL（如 `https://gitea.example.com`，Gitea 上等同 `gitea.server_url`，用于拼接 API 地址，禁止硬编码 `server:3500`） |
| `github.api_url` | API 根 URL（如 `https://gitea.example.com/api/v1`，Gitea 上等同 `gitea.api_url`） |
| `github.actor` | 触发用户 |
| `github.event_name` | 触发事件名（`push` / `pull_request` 等） |
| `github.event` | 完整 webhook payload |
| `github.head_ref` | PR 源分支（仅 PR 事件） |
| `github.base_ref` | PR 目标分支（仅 PR 事件） |
| `github.workflow` | workflow 名 |

## 输出与依赖引用

- 同 job 内：`steps.<step_id>.outputs.<name>`（step 用 `echo "x=y" >> $GITHUB_OUTPUT` 写）
- 跨 job：`needs.<job_id>.outputs.<name>`（需 job 定义 `outputs`，且当前 job 声明 `needs`）
- job 定义输出：
  ```yaml
  jobs:
    job1:
      outputs:
        matrix: ${{ steps.set-matrix.outputs.matrix }}
  ```

## 上下文可用性限制（关键）

不同 workflow 键能用的上下文**不同**。常见限制：

| 位置 | 可用上下文 |
|------|-----------|
| `run-name` / `concurrency` | `github`, `inputs`, `vars` |
| 顶层 `env` | `github`, `secrets`, `inputs`, `vars` |
| `jobs.<id>.if` | `github`, `needs`, `vars`, `inputs` |
| `jobs.<id>.steps.if` | `github`, `needs`, `strategy`, `matrix`, `job`, `runner`, `env`, `vars`, `steps`, `inputs`（**无 `secrets`**） |
| `jobs.<id>.steps.env` | `github`, `needs`, `strategy`, `matrix`, `job`, `runner`, `env`, `vars`, `steps`, `inputs`, `secrets` |
| `jobs.<id>.steps.run` | 同上（有 `secrets`） |
| `jobs.<id>.steps.with` | 同上（有 `secrets`） |
| `jobs.<id>.outputs.<name>` | `github`, `needs`, `strategy`, `matrix`, `job`, `runner`, `env`, `vars`, `secrets`, `steps`, `inputs` |
| `jobs.<id>.runs-on` | `github`, `needs`, `strategy`, `matrix`, `vars`, `inputs` |

- `secrets` 可用性限制：
  - **不能**用于 `if` 条件（`jobs.<id>.if` 与 step 级 `if` 均无 `secrets`）
  - **可以**用于顶层 `env`、job 级 `env`、**step 级 `env`**、`with`、`run` 命令内（官方可用性表：`steps.env` 含 `secrets`）
- `hashFiles` 仅在 `steps.*` 的某些键可用

## 变量 vs 上下文

- **默认环境变量**（`GITHUB_SHA`、`GITHUB_REF`、`GITHUB_WORKSPACE` 等）：仅 runner 上存在，运行时才可用
- **上下文**（`github.*` 等）：可在 runner 分派前的 `if` / `env` 等位置使用
- 二者用途不同：`if` 判断用上下文（分派前），步骤内脚本用环境变量或上下文都行
