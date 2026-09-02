# Workflow 语法要点（GitHub Actions）

> 官方源：https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
> 本文件为提炼要点，官方文档为准；不确定的细节请回查官方源。

## 基本规则

- 文件必须是 `.yml` / `.yaml`，存放于仓库根目录 `.github/workflows/` 下
- 顶层键：`name`、`run-name`、`on`、`permissions`、`env`、`concurrency`、`defaults`、`jobs`
- `name` 省略时显示文件路径；`run-name` 可含表达式（如 `Deploy by @${{ github.actor }}`）

## `on`（触发条件）

- 单事件：`on: push`
- 多事件：`on: [push, fork]`
- 事件活动类型：`on.<event>.types: [opened, synchronize]`
- 过滤器（branches / paths / tags）：
  ```yaml
  on:
    push:
      branches: [main, 'releases/**']
      tags: ['v*']
      paths: ['**.js']
  ```
- **注意**：`branches` 与 `branches-ignore` 不能同时用；排除用 `!` 前缀（`'!releases/**-alpha'`），且必须有至少一个非 `!` 模式
- `paths` 过滤：push 用 two-dot diff，PR 用 three-dot diff；超过 1000 提交 / diff 超时 → workflow 必定运行
- `schedule`：POSIX cron 5 字段，最短 5 分钟，默认 UTC，可加 `timezone`
  ```yaml
  on:
    schedule:
      - cron: '30 5 * * 1-5'
        timezone: "America/New_York"
  ```
- `workflow_dispatch`：手动触发，可定义 `inputs`（`type`: `boolean`/`choice`/`number`/`string`），仅默认分支上的文件触发
- `workflow_dispatch` 完整 inputs 语法（含 `choice` 选项）：
  ```yaml
  on:
    workflow_dispatch:
      inputs:
        environment:
          description: '部署环境'
          required: true
          default: 'staging'
          type: choice
          options:
            - production
            - staging
        debug:
          description: '是否开启调试'
          required: false
          type: boolean
  ```
  - `type` 合法值仅 `boolean` / `choice` / `number` / `string`（**没有** `environment`；`environment` 是 job 级部署环境键，不是输入类型）
  - 输入在 `${{ inputs.<name> }}` 中读取
- `workflow_call`：可复用工作流，定义 `inputs`（必带 `type`）、`outputs`、`secrets`
- `workflow_run`：在其他 workflow 完成/请求后触发，如 `on.workflow_run.workflows: ["Build"]`

## `permissions`（GITHUB_TOKEN 权限）

- 可顶层或 job 级；取值 `read` / `write` / `none`（`write` 含 `read`）
- **指定任一权限后，未指定的权限全部为 `none`**（最小权限原则）
- 常用权限：`actions`、`checks`、`contents`、`deployments`、`discussions`、`issues`、`packages`、`pull-requests`、`security-events`、`statuses`
- 示例（创建 Release）：
  ```yaml
  permissions:
    contents: write
  ```

## `jobs`

- `jobs.<id>`：`runs-on`、`needs`、`if`、`steps`、`strategy`、`services`、`container`、`timeout-minutes`、`continue-on-error`、`outputs`、`env`、`defaults`、`permissions`、`concurrency`
- `needs`：声明依赖，串行执行；`needs: [job1, job2]`
- `if`：条件执行，默认含 `success()`；用状态函数覆盖需显式写 `if: ${{ failure() }}` 等
- `runs-on`：GitHub-hosted（`ubuntu-latest` / `windows-latest` / `macos-latest`）或自托管（labels）
- `timeout-minutes`：job 超时（默认 360，hosted 上限因 runner 而异）
- `continue-on-error: true`：失败不阻塞后续 job

### `jobs.<id>.strategy.matrix`

- 定义变体组合：`strategy: { matrix: { os: [ubuntu, windows], node: [18, 20] } }`
- 引用：`${{ matrix.os }}`、`${{ matrix.node }}`
- 组合排除：`exclude: [{ os: ubuntu, node: 18 }]`
- 动态矩阵：`include` + `fromJSON()` 可生成（从其他 job output 传入）

### `jobs.<id>.steps`

- `uses`：引用 action（`actions/checkout@v7`）或本地 action（`./.github/actions/my-action`）
- `run`：执行 shell 命令（可多行 `|`）
- `with`：action 输入参数
- `env`：step 环境变量
- `id`：给 step 命名，供 `steps.<id>.outputs.<name>` 引用
- `if`：step 级条件
- `continue-on-error`、`timeout-minutes`、`working-directory`、`shell`

### Job outputs 传递

- 定义：`jobs.<id>.outputs.<name>: ${{ steps.<step_id>.outputs.<output_name> }}`
- step 写输出：`echo "name=value" >> $GITHUB_OUTPUT`
- 跨 job 引用：`${{ needs.<job_id>.outputs.<output_name> }}`

## 常用 action 与版本提示

| action | 用途 | 常用版本 | 关键参数 |
|--------|------|---------|----------|
| `actions/checkout` | 检出仓库代码 | `@v7` | 无 |
| `actions/setup-node` | 配置 Node 环境 | `@v7` | `node-version`（如 `'20'` 或 `${{ matrix.node }}`） |
| `actions/setup-python` | 配置 Python 环境 | `@v7` | `python-version` |
| `actions/setup-go` | 配置 Go 环境 | `@v7` | `go-version` |
| `actions/upload-artifact` | 上传工件 | `@v7` | `name`、`path` |
| `actions/download-artifact` | 下载工件 | `@v7` | `name`、`path` |
| `actions/cache` | 依赖缓存 | `@v6` | `path`、`key`（常配 `hashFiles()`） |
| `softprops/action-gh-release` | 创建 GitHub Release | `@v3` | `tag_name`、`name`、`body_path` |

> **升级 action 到新 major 时**：先查该 action 的最新版本与 release notes，确认参数无破坏性变更。查询方式（实测验证）：
>
> ```bash
> # 推荐：gh CLI（已认证，限流 5000 次/时）——不要用 WebFetch 直接抓 api.github.com
> gh api repos/actions/checkout/releases/latest --jq .tag_name
> ```
>
> - **WebFetch 直接抓 `api.github.com` 必 403**：GitHub API 强制 User-Agent 头（WebFetch 无法自定义）+ 匿名限流仅 60 次/时/IP，实测双 403
> - 无 gh 的兜底：`curl -H "User-Agent: xxx" https://api.github.com/...`（能过 UA 检查但仍有匿名限流）；或 WebFetch 抓 `https://github.com/<owner>/<repo>/releases/latest`（HTML 页面，绕过 API 限流，从 "Releases vX.Y.Z" 中读版本，噪音大）
>
> 版本号会随时间演进，编写时点后请核实最新 major（本表基于 2026-09 官方 latest）。

### Node.js 项目典型步骤

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: actions/setup-node@v7
    with:
      node-version: ${{ matrix.node }}   # 或固定 '20'
  - run: npm ci                          # 安装依赖（需 package-lock.json；无 lock 文件用 npm install）
  - run: npm test                        # 跑测试
  - run: npm run build                   # 构建
```

### 写 job output 的标准方式

```bash
echo "name=value" >> $GITHUB_OUTPUT
```

（旧 `::set-output` 语法已废弃，勿用。）

## 陷阱提醒

- **tag 触发时 checkout 处于 detached HEAD**：`actions/checkout@v7` 检出 tag 指向的提交，不在分支上。此时若需 `git push` 回仓库，必须 `git push origin HEAD:main`（显式指定分支），否则报 `fatal: You are not currently on a branch`
- `run-name`、`concurrency`、`env`、`if` 等位置可用的上下文有严格限制（见 contexts.md）
- 表达式 `${{ }}` 中字符串必须单引号；`if` 里布尔上下文注意字符串 vs 布尔转换

## 完整示例：CI workflow（可照抄骨架）

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:                        # PR 上跑检查
  workflow_dispatch:                   # 手动触发
    inputs:
      environment:
        description: '部署环境'
        required: true
        default: 'staging'
        type: choice
        options: [production, staging]

permissions:
  contents: read                        # 最小权限

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node: [18, 20]   # 用受支持的 LTS 版本（2026 年建议 20+；Node 18 已 EOL）
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: ${{ matrix.node }}
      - run: npm ci
      - run: npm test

  deploy:
    needs: test                         # 依赖 test job
    if: github.ref == 'refs/heads/main' # 仅 main 分支
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploy to ${{ inputs.environment || 'staging' }}"
```
