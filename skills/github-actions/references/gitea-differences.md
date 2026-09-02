# Gitea Actions 差异要点（相对 GitHub Actions）

> 官方源：https://docs.gitea.com/usage/actions/（comparison / faq / quickstart / design 页面）
> 本文件是同一技能内 GitHub references 的 **Gitea 补充差异文件**；GitHub 侧语法详见同目录其余文件。
> **版本声明**：Gitea 的语法支持**随版本演进**（例如表达式函数 1.27 仅 `always()`，1.28 起支持标准 GitHub 函数）。本文件标注了 1.27（主流稳定版）与 1.28+ 的变化，但**任何时刻以官方文档当前稳定版为准**。

## 第一步：确认目标平台（硬性）

- **GitHub** → 用本目录 GitHub references（workflow-syntax / events / expressions / contexts）
- **Gitea** → 本文件 **必读**；且因 Gitea 语法随版本演进，**必须访问 https://docs.gitea.com/usage/actions/ 核验当前版本**（重点看 comparison 与 faq 页面），本地文件仅是起点摘要，不得视为最终权威
- 两平台语法重叠度约 95%，大多数 workflow 骨架可直接互相迁移；差异集中在本文列出的点上

## 基本事实与文件位置

| 项 | GitHub | Gitea |
|----|--------|-------|
| 工作流目录 | `.github/workflows/` | `.gitea/workflows/`（官方推荐；`.github/workflows/` 也识别，仅作迁移回退，两处勿放同一工作流） |
| 文件后缀 | `.yml` / `.yaml` | 同 |
| 是否默认启用 | 开箱即用 | 实例级默认启用（1.21+，1.21 前需 `[actions] ENABLED=true`）+ **仓库级需手动开启**（Settings → Enable Repository Actions） |
| 执行者 | GitHub-hosted / 自托管 runner | 需自建 Gitea Runner（act 的硬 fork，官方建议与 Gitea 实例分机部署） |
| `runs-on` | hosted 镜像或自托管 labels | 标签映射到环境：`ubuntu:22.04` 等（注册时可自定义 `label:docker://image` 或 `label:host`） |
| 内置 token | `GITHUB_TOKEN` | `GITEA_TOKEN` |

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
| 复杂 `runs-on`（`runs-on: {group:, labels:}` 形式） | 始终不支持 | 1.27：仅 `runs-on: xyz` / `[xyz]`；1.28+：额外支持表达式形式（`runs-on: ${{ 条件 && 'ubuntu-latest' \|\| 'self-hosted' }}` 及含表达式的数组） |
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

## 语法支持随版本演进（务必核验实例版本）

| 能力 | 1.27（当前主流稳定版） | 1.28+（next 文档） |
|------|----------------------|--------------------|
| 表达式函数 | 仅 `always()` 受支持（官方 comparison 原文） | 支持标准 GitHub 函数（`success()` / `failure()` / `always()` / `cancelled()` / `format()` / `toJSON()`） |
| `runs-on` | 仅静态字符串或标签数组 | 额外支持字符串表达式与含表达式的数组（`{group:, labels:}` 形式仍不支持） |
| 表达式运算符/插值 | 可用（`==`、`&&`、`${{ gitea.ref }}`） | 可用 |

- 结论：**v1.27 目标仓库默认不用函数**；目标实例为 1.28+ 时以 https://docs.gitea.com/next/usage/actions/comparison/ 当前内容为准。不确定时优先用运算符/事件过滤，并在交付前核验实例版本

## actionlint 校验（GitHub 与 Gitea 均可用）

actionlint 本身无官方 Gitea 模式，但 Gitea 官方仓库与 act_runner 均依赖它做表达式求值/语法校验（1.28 起为直接依赖）。支持单文件 / 多文件 / glob / stdin（`-`）任一形态：

```bash
# 单文件
actionlint .gitea/workflows/ci.yaml
# Gitea 全部工作流（显式传路径，默认只扫 .github/workflows/）
actionlint .gitea/workflows/*.yml

# 已知误报处理：
# 1) ${{ gitea.* }} → undefined variable "gitea"：改用 github.*（官方确认功能等同）或 -ignore
# 2) runner 过旧类误报（如 Gitea act_runner 仍用 upload-artifact@v3）：
actionlint -ignore='the runner of "actions/upload-artifact@v3(\.[0-9]+\.[0-9]+)?" action is too old to run on GitHub Actions' .gitea/workflows/*.yml
```

- actionlint 版本升级可能引入新规则导致误报（Gitea 官方即因此锁定版本），CI 中建议固定版本
- 绝对 URL 的 `uses: https://...` 不会被纯语法检查报错（仅 `actions` 附加规则在执行时检查）

## 从 GitHub 迁移到 Gitea 的检查清单

1. 目录改为 `.gitea/workflows/`（确认仓库已启用 Actions）
2. 删除 `jobs.*.environment`（被忽略）
3. `runs-on` 保持单标签/标签列表形式
4. 表达式函数按目标实例版本核查（1.27 换用运算符/事件过滤）
5. `permissions` 移除 GitHub 专属 scope（statuses/checks/deployments/id-token/security-events/pages）
6. `GITHUB_TOKEN` 相关操作改用 `GITEA_TOKEN`（注意包发布未实现，需 PAT）
7. PR 分支判断依赖 `ref == refs/heads/main` 的写法在 Gitea 天然成立，无需改
8. 内网实例：核对 action 下载源（DEFAULT_ACTIONS_URL / 绝对 URL / 镜像）
9. 自托管 Windows runner：默认 shell 是 bash，加 `defaults: {run: {shell: powershell}}`