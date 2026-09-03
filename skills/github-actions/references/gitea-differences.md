# Gitea Actions 差异要点（相对 GitHub Actions）

> 官方源：https://docs.gitea.com/usage/actions/（comparison / faq / quickstart / design 页面）
> 本文件是同一技能内 GitHub references 的 **Gitea 补充差异文件**；GitHub 侧语法详见同目录其余文件。
> **维护模式**：Agent 无需也不应访问官方文档核验版本差异；实例升级后的文档更新由维护者负责。
> **版本声明**：语法能力随版本演进（1.27 仅 `always()`，1.28+ 起支持标准 GitHub 函数），默认按"当前默认版本"（1.27）编写；能力明细见下文"版本演进表"与"版本策略"。

## 第一步：确认目标平台（硬性）

- **GitHub** → 用本目录 GitHub references（workflow-syntax / events / expressions / contexts）
- **Gitea** → 本文件 **必读**；语法按"版本策略"小节处理：**默认按"当前默认版本"（1.27）编写，无需访问官方文档**；用户要求高版本特性（如 1.28 表达式函数）时向用户确认版本，按本文件版本演进表编写
- 两平台语法重叠度约 95%，大多数 workflow 骨架可直接互相迁移；差异集中在本文列出的点上

## 基本事实与文件位置

| 项 | GitHub | Gitea |
|----|--------|-------|
| 工作流目录 | `.github/workflows/` | `.gitea/workflows/`（官方推荐；`.github/workflows/` 也识别，仅作迁移回退，两处勿放同一工作流） |
| 文件后缀 | `.yml` / `.yaml` | 同 |
| 是否默认启用 | 开箱即用 | 实例级默认启用 + **仓库级需手动开启**（Settings → Enable Repository Actions） |
| 执行者 | GitHub-hosted / 自托管 runner | 需自建 Gitea Runner（act 的硬 fork，官方建议与 Gitea 实例分机部署） |
| `runs-on` | hosted 镜像或自托管 labels | 标签映射 job 容器镜像（默认官方 `docker.gitea.com/runner-images:*` 系列，见"job 容器镜像"节；注册时可自定义 `label:docker://image` 或 `label:host`） |
| 内置 token | `GITHUB_TOKEN`（自动注入环境变量，开箱即用） | `GITEA_TOKEN`（**不裸注入**：仅 `${{ secrets.GITEA_TOKEN }}` 可用，步骤内需显式 env 注入，见下文） |

## 直接可用的语法（官方确认，放心照抄）

- 顶层键 `name` / `run-name` / `on` / `env` / `concurrency` / `defaults` / `jobs` / `permissions` 均支持（官方 quickstart demo 即含 `run-name` 与 `${{ job.status }}`）
- 事件语法与 GitHub 兼容：`push`（branches/tags/paths 过滤）、`pull_request`、`workflow_dispatch`、`schedule`、`workflow_call`、`workflow_run`、`release`、`issues` 等；`pull_request` 默认 `opened/reopened/synchronize`，与 GitHub 一致
- `strategy.matrix`、`needs`、`if`（`==` 等运算符与 `${{ }}` 字面量）、`steps` 的 `uses`/`run`/`with`/`env`/`id`、job outputs（`echo "x=y" >> $GITHUB_OUTPUT`）、`timeout-minutes`、`continue-on-error`、`services`、`container`
- 上下文 `github.*` **完全等同** `gitea.*`（官方 FAQ：两者功能一致，推荐 `gitea.*` 以兼容未来 Gitea 专属字段；用 `github.*` 也能正常运行，且能通过 actionlint 检查——见下文校验）
- `actions/checkout@v4` 等第三方 action 直接可用（默认从 github.com 下载，见下文"action 下载"）

## Gitea 专属特性（GitHub 没有）

- **绝对 URL 引用 action**：`uses: https://gitea.com/owner/repo@branch` / `uses: http://你的实例/owner/repo@branch`（GitHub 只认站内 action）
- **Go 编写的 action**（见官方 Creating Go Actions 博客）
- `schedule` 支持非标准 cron：`@yearly` / `@monthly` / `@weekly` / `@daily` / `@hourly`（GitHub 不支持）

## GitHub 语法在 Gitea 不支持 / 被忽略（重点）

| 项 | Gitea 行为 | 替代方案 |
|----|-----------|---------|
| `jobs.<job_id>.environment`（部署环境） | **忽略** | 用 `if` + 手动映射环境名 |
| 复杂 `runs-on`（`runs-on: {group:, labels:}` 形式） | 始终不支持 | 1.27 仅静态/标签数组；1.28+ 支持表达式形式（见版本演进表） |
| 表达式**函数**（1.27 版） | 官方文档：仅 `always()` 受支持（限制针对**函数**） | `==`/`!=`/`&&`/`\|\|`/`!` 运算符、上下文插值（`${{ gitea.ref }}`）、字符串/布尔字面量均**可用**（官方 FAQ 与 quickstart 示例证实），勿因函数限制过度规避全部 `${{ }}`；分支/标签判断优先事件过滤（`tags: ['v*']`）；1.28+ 已支持标准函数（见下文） |
| `permissions` 的 GitHub 专属 scope | 不支持 `statuses` / `checks` / `deployments` / `id-token` / `security-events` / `pages` | 用 Gitea 专属 scope：`code` / `releases` / `wiki` / `projects`；其余（`contents` 等）通用 |
| Problem Matchers、错误注解 workflow 命令 | 忽略 | 无替代（不影响执行） |
| `GITEA_TOKEN` 发布到包仓库 | 未实现 | 使用 PAT |

## 行为差异（写法相同、表现不同）

- **PR 的 `ref`**：GitHub 是 `refs/pull/:num/merge`（合并预览），Gitea 是 `refs/pull/:num/head`（PR 头部）——用 `github.ref == 'refs/heads/main'` 判断分支在 Gitea PR 上恒为 false，天然免疫 PR 误触发
- **`permissions` 生效规则**：有效权限被仓库/组织设置"钳制"，fork PR 与跨仓库访问进一步受限
- **上下文可用性不检查**：`env` 等上下文可用位置比 GitHub 宽松（GitHub 有限制的写法在 Gitea 也能跑，反向迁移时注意）
- **action 下载源**：非全限定 action（如 `actions/checkout@v4`）默认从 `github.com` 下载脚本；内网实例可配置 `[actions].DEFAULT_ACTIONS_URL = self`（只允许 `github` / `self` 两值），或镜像 action 到本实例后用绝对 URL
- runner 对多标签 `runs-on: [a, b]` 采用"取第一个匹配"逻辑（不是 GitHub 的 AND 匹配），跨标签需求慎用

## 内置 token 与 CI 回推（实测注意）

- **Gitea 内置 token 不裸注入环境变量**（实测踩坑）：GitHub 的 `GITHUB_TOKEN` 自动出现在 job 环境里；Gitea 的 `GITEA_TOKEN` **只通过 `${{ secrets.GITEA_TOKEN }}` 暴露**——步骤里直接引用裸 `${GITEA_TOKEN}` 得到空值（实测 push 报 `Failed to authenticate user`）。必须显式注入：
  ```yaml
  - run: git push "https://oauth2:${GITEA_TOKEN}@<实例>/<owner>/<repo>.git" HEAD:main
    env:
      GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}
  ```
- **`GITEA_TOKEN` 是内置 token、开箱即用**（官方 token-permissions 文档确认：每个 job 自动获得，`${{ secrets.GITEA_TOKEN }}` 直接可用）——**无需**在仓库 UI 手动配置同名 secret（若手动配了同名 secret 会**覆盖**内置 token）。它的权限由 `permissions`（workflow/job 级）+ 仓库/组织 `Settings → Actions → General` 的默认/最大权限设置共同决定
- **CI 内回推产物**（自动更新类 workflow）标准写法：`git add` 限定产物目录（如 `docs/`）→ `git diff --cached --quiet` 判空则跳过提交（幂等）→ commit → 用内置 token 的 URL 显式 push。schedule / workflow_dispatch 触发时 checkout 处于 detached HEAD，必须 `git push ... HEAD:main` 显式指定分支
- `permissions.contents: write` 足够支持回推（对应 Gitea 的 `code: write`）；实际生效权限还受仓库/组织的 MaxTokenPermissions 设置钳制

## job 容器镜像

- 用 `docker.gitea.com/runner-images:ubuntu-latest`

## 语法支持随版本演进（默认按当前默认版本 1.27 编写，见"版本策略"）

| 能力 | 1.27（当前主流稳定版） | 1.28+（next 文档） |
|------|----------------------|--------------------|
| 表达式函数 | 仅 `always()` 受支持（官方 comparison 原文） | 支持标准 GitHub 函数（`success()` / `failure()` / `always()` / `cancelled()` / `format()` / `toJSON()`） |
| `runs-on` | 仅静态字符串或标签数组 | 额外支持字符串表达式（`runs-on: ${{ 条件 && 'ubuntu-latest' \|\| 'self-hosted' }}`）与含表达式的数组（`[linux, "${{ ... }}"]`）；`{group:, labels:}` 形式仍不支持 |
| 表达式运算符/插值 | 可用（`==`、`&&`、`${{ gitea.ref }}`） | 可用 |

### 版本策略（默认按 1.27 编写）

> **当前默认版本：1.27**（维护者升级 Gitea 实例后更新此标记，如改为 1.28）

**【默认】按"当前默认版本"（1.27）的语法编写，无需任何探测、无需出网**：

- 不用表达式函数（1.27 官方文档仅 `always()`）、不用 `environment`、不用复杂/表达式 runs-on
- 用事件过滤（`tags: ['v*']`）、`==`/`&&`/`!` 运算符、上下文插值（`${{ gitea.ref }}`）、单 label 或静态字符串 `runs-on`、`contents: read`
- 1.27 写法在 1.28+ 上完全兼容（1.28 是能力超集），实例升级后存量 workflow 无需改动

**【目标版本 ≠ 默认版本】仅当用户明确要求高版本特性（如 1.28 表达式函数）时**才有必要确认真实版本——**版本事实必须来自用户/维护者**：

- 用户没说版本 → **直接询问用户**（一条消息成本最低），**不得自行探测、不得访问官方文档核验、不得臆造**
- 用户/维护者告知或确认版本后 → 对照版本演进表判定可用语法（例：1.27.x → 表达式函数仅 `always()`；1.28.x → 标准函数可用）
- 用户无法确认版本 → 按"当前默认版本"（1.27）编写并告知限制

### 语法兼容性取决于实例版本，而非 runner 版本（官方文档确认）

- Gitea 实例负责**解析 workflow、求值表达式、展开 matrix/runs-on、调度 job**——runner 拉取的是解析后的任务而非 YAML 文件。因此"哪些语法可用"（键、事件、表达式函数、runs-on 形式、permissions scope）**只取决于实例版本**（1.27 仅 `always()`、1.28 起集成 actionlint 求值，均为实例侧能力）
- Gitea Runner 与实例**独立发版**，只负责执行层（容器/宿主机步骤、action 下载、日志流）——语法兼容性只看实例版本，不看 runner
- 实践：语法支持与否 → 看目标实例版本（由用户/维护者确认）；action 能否执行（如 v7 系列要求 Node 24 运行时）→ 看 runner 与镜像版本

## actionlint 校验（GitHub 与 Gitea 均可用）

actionlint 可校验 Gitea workflow（自身无 Gitea 模式，按 GitHub 语法近似校验），支持单文件 / 多文件 / stdin（`-`）任一形态：

```bash
# 单文件
actionlint .gitea/workflows/ci.yaml
# Gitea 全部工作流（显式传路径，默认只扫 .github/workflows/）
actionlint .gitea/workflows/ci.yaml .gitea/workflows/release.yaml   # 逐个列出

# 已知误报处理：
# 1) ${{ gitea.* }} → undefined variable "gitea"：改用 github.*（官方确认功能等同）直接通过，
#    或 -ignore 'undefined variable "gitea"'
# 2) runner 过旧类误报：
actionlint -ignore='the runner of "actions/upload-artifact@v3(\.[0-9]+\.[0-9]+)?" action is too old to run on GitHub Actions' .gitea/workflows/ci.yaml .gitea/workflows/release.yaml
```

> **Windows/pwsh 注意（实测）**：通配符 `*.yml` 不会被 pwsh 展开（见 SKILL.md「校验方法」），**逐个列出文件**或先用 `Get-ChildItem ... *.yml` 展开再传。Linux/macOS bash 下 shell 会自动展开 glob。

- actionlint 版本升级可能引入新规则导致误报，CI 中建议固定版本
- 绝对 URL 的 `uses: https://...` 不会被纯语法检查报错（仅 `actions` 附加规则在执行时检查）

## 从 GitHub 迁移到 Gitea 的检查清单

1. 目录改为 `.gitea/workflows/`（确认仓库已启用 Actions）
2. 删除 `jobs.*.environment`（被忽略）
3. `runs-on` 保持单标签/标签列表形式
4. 表达式函数一律不用（默认 1.27）；仅用户确认实例为 1.28+ 且要求时按版本表启用
5. `permissions` 移除 GitHub 专属 scope（statuses/checks/deployments/id-token/security-events/pages）
6. `GITHUB_TOKEN` 相关操作改用 `GITEA_TOKEN`（**须 `env: GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}` 显式注入，不裸注入**；包发布未实现需 PAT）
7. PR 分支判断依赖 `ref == refs/heads/main` 的写法在 Gitea 天然成立，无需改
8. 内网实例：核对 action 下载源（DEFAULT_ACTIONS_URL / 绝对 URL / 镜像）
9. 自托管 Windows runner：默认 shell 是 bash，加 `defaults: {run: {shell: powershell}}`