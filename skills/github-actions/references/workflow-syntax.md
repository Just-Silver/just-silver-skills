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
- `workflow_dispatch`：手动触发，可定义 `inputs`（`type`: `boolean`/`choice`/`number`/`environment`/`string`），仅默认分支上的文件触发；顶层 input 最多 25 个，payload ≤ 65,535 字符
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
        deploy_env:
          description: '选择仓库 Environment（仅 GitHub）'
          required: false
          type: environment
  ```
  - `type` 合法值：`boolean` / `choice` / `number` / `environment` / `string`
  - `environment` 类型用于选择仓库已配置的 Environment，`inputs.<name>` 得到环境名字符串；**是否施加保护规则仍取决于 job 级 `environment:`**（输入本身不等于环境门禁）
  - `options` 仅对 `choice` 合法；给其他类型写 `options` 会使 workflow 无效
  - 输入在 `${{ inputs.<name> }}` 中读取；`github.event.inputs` 中同值但全部转成字符串（`boolean` 也不会保留布尔类型）
  - **Gitea 28.4 无 Environments 概念**：`type: environment` 不会被识别为环境选择（28.4 Web 表单只特判 `choice` / `boolean` / `number`，其余按文本框），也没有环境保护规则；实测 28.x 可解析并通过 API 传值，但没有环境语义。Gitea 目标用 `string` / `choice`，门禁用 `if` + 分支保护
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

## `concurrency`（并发互斥 / 待排队上限）

- 两级作用域：顶层（整个 workflow run）与 `jobs.<id>.concurrency`（单个 job）。**同名 `group` 跨 workflow 也互斥**——多 workflow 回推排队的关键就靠这一点。
- 同一 group 同时最多 **1 个 running**；新运行时若已有 running，新运行进入 `pending`。
- **默认 `queue: single`**：`pending` 也只保留 1 个；再来的运行会取消旧 `pending` 并顶替它。所以 `cancel-in-progress: false` **不是可靠队列**——它只保证 running 不被取消，不保证多个待跑都保留。
- `cancel-in-progress: true`：新运行取消同组 running（以及 pending），常用于 CI 省 runner 分钟。
- `queue: max`：把 `pending` 上限提高到 **100**；队列满后新运行被取消；按开始等待的时间 FIFO，但**顺序不保证**。**不能与 `cancel-in-progress: true` 同用**（workflow 校验错误）。
- 写法：字符串简写等价于只设 group（`cancel-in-progress` 默认 false、`queue` 默认 single）：
  ```yaml
  concurrency: ci-${{ github.ref }}
  # 等价于
  concurrency:
    group: ci-${{ github.ref }}
    cancel-in-progress: false
    queue: single
  ```
- 需要容纳多个待跑运行时显式写 `queue: max`：
  ```yaml
  concurrency:
    group: pushback-${{ github.ref }}
    queue: max
    cancel-in-progress: false      # 与 queue: max 搭配时必须为 false/省略
  ```
  > actionlint 1.7.12 尚未认识 `queue`，会报 `unexpected key "queue"`；用 `-ignore 'unexpected key "queue"'` 放行（SKILL.md「校验」）。
- `group` 命名：常用 `${{ github.ref }}` 按分支隔离；**需互斥的多个 workflow 必须用完全相同的 `group` 名**（如 `pushback-${{ github.ref }}`），否则各排各的队，照样冲突。group 名**大小写不敏感**（`prod` 与 `Prod` 同组）。
- 可用上下文：顶层 `concurrency` 仅 `github` / `inputs` / `vars`；`jobs.<id>.concurrency` 还可用 `needs` / `strategy` / `matrix`（见 contexts.md）。
- **Gitea 28.4**：支持 `group` 与 `cancel-in-progress`（含表达式），但**不支持 `queue`**（`queue: max` 仍是 open proposal，见 go-gitea/gitea#39195）；其行为固定为只保留一个 pending（新 pending 替换旧 pending），等同 GitHub 的 `queue: single`。Gitea 目标不要照搬 `queue: max`，也不能把 `cancel-in-progress: false` 当作多任务队列。

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
- step 写输出：见下文"写 job output 的标准方式"
- 跨 job 引用：`${{ needs.<job_id>.outputs.<output_name> }}`

## 常用 action 与版本提示

| action | 用途 | 常用版本 | 关键参数 |
|--------|------|---------|----------|
| `actions/checkout` | 检出仓库代码 | `@v7` | 无 |
| `actions/setup-node` | 配置 Node 环境 | `@v7` | `node-version`（如 `'20'` 或 `${{ matrix.node }}`） |
| `actions/setup-python` | 配置 Python 环境 | `@v7` | `python-version` |
| `actions/setup-go` | 配置 Go 环境 | `@v7` | `go-version` |
| `actions/upload-artifact` | 上传工件 | `@v7` | `name`、`path` |
| `actions/download-artifact` | 下载工件 | `@v8` | `name`、`path` |
| `actions/cache` | 依赖缓存 | `@v6` | `path`、`key`（常配 `hashFiles()`） |
| `softprops/action-gh-release` | 创建 GitHub Release | `@v3` | `tag_name`、`name`、`body_path` |

> **版本核对（2026-11-20 经 `gh api repos/<owner>/<repo>/releases/latest` 实测）**：以上"常用版本"即各 action 的**当前最新 major**。写新 workflow 前建议再复核（major 可能已升级），并看 release notes 确认参数无破坏性变更。个别 action 最新 major 与文档不符时以实测为准并更新本表。**不要因为看到新 major 就批量升级**：Gitea 侧还要核对目标 Runner 的 Node 运行时与镜像兼容性。

### 写 job output 的标准方式

```bash
echo "name=value" >> $GITHUB_OUTPUT
```

（旧 `::set-output` 语法已废弃，勿用。）

## 陷阱提醒

- **tag 触发时 checkout 处于 detached HEAD**：`actions/checkout@v7` 检出 tag 指向的提交，不在分支上。此时若需 `git push` 回仓库，必须 `git push origin HEAD:main`（显式指定分支），否则报 `fatal: You are not currently on a branch`
- `run-name`、`concurrency`、`env`、`if` 等位置可用的上下文有严格限制（见 contexts.md）
- `if` 里布尔上下文注意字符串 vs 布尔转换（字符串须单引号，见 expressions.md）

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
