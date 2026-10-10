# Gitea Actions 差异要点（相对 GitHub Actions）

> 官方源：https://docs.gitea.com/usage/actions/（comparison / faq / quickstart / token-permissions / design 页面；右上角可切换目标版本）+ Gitea Runner 仓库文档 https://gitea.com/gitea/runner
> 本文件是同一技能内 GitHub references 的 **Gitea 补充差异文件**；GitHub 侧语法详见同目录其余文件。
> **定位**：本文件是维护者提炼的**常见差异速查，不是版本能力的最终权威**；与官方文档冲突时**以官方文档为准**。语法/权限存疑应核对 docs.gitea.com 对应版本文档，**不禁止 Agent 查证**。
> **版本声明（本技能只覆盖此区间，不做旧版本兼容）**：目标为 **Gitea Server 28.x**（当前稳定版 28.1.0）+ **Gitea Runner 5.x**。Gitea 已去掉历史 `1.` 前缀（28.0.0 = 原 1.28.0）。**1.27 及更早不在支持范围**——目标过旧时请查该版本官方文档，不要套用本文能力。

## 第一步：确认目标平台（硬性）

- **GitHub** → 用本目录 GitHub references（workflow-syntax / events / expressions / contexts）
- **Gitea** → 本文件 **必读**；**默认按 Gitea 28.x + Runner 5.x 编写**（见"版本声明"）。`github.*` 与 `gitea.*` 等价，推荐 `gitea.*`；**实例若明显过旧（1.27 及以前）须先确认并改查对应版本文档**，不要臆造高版本能力
- 两平台语法重叠度约 95%，大多数 workflow 骨架可直接互相迁移；差异集中在本文列出的点上

## 基本事实与文件位置

| 项 | GitHub | Gitea |
|----|--------|-------|
| 工作流目录 | `.github/workflows/` | `.gitea/workflows/`（官方推荐；`.github/workflows/` 也识别，仅作迁移回退，两处勿放同一工作流） |
| 文件后缀 | `.yml` / `.yaml` | 同 |
| 是否默认启用 | 开箱即用 | 实例级默认启用 + **仓库级需手动开启**（Settings → Enable Repository Actions） |
| 执行者 | GitHub-hosted / 自托管 runner | 需自建 **Gitea Runner 5.x**（act 的硬 fork，官方建议与 Gitea 实例分机部署） |
| `runs-on` | hosted 镜像或自托管 labels | 标签映射 job 容器镜像（默认官方 `docker.gitea.com/runner-images:*` 系列，见"job 容器镜像"节；注册时可自定义 `label:docker://image` 或 `label:host`） |
| 内置 token | `GITHUB_TOKEN`（自动注入环境变量，开箱即用） | `GITEA_TOKEN`（**不裸注入**：仅 `${{ secrets.GITEA_TOKEN }}` 可用，步骤内需显式 env 注入，见下文） |

## 直接可用的语法（官方确认，放心照抄）

- 顶层键 `name` / `run-name` / `on` / `env` / `concurrency` / `defaults` / `jobs` / `permissions` 均支持（官方 quickstart demo 即含 `run-name` 与 `${{ job.status }}`）
- 事件语法与 GitHub 兼容：`push`（branches/tags/paths 过滤）、`pull_request`、`workflow_dispatch`、`schedule`、`workflow_call`、`workflow_run`、`release`、`issues` 等；`pull_request` / `pull_request_target` 默认 `opened/reopened/synchronize`，与 GitHub 一致（事件与 activity type 明细见官方 FAQ 表）
- **表达式支持标准 GitHub 函数与上下文**（28.x 官方 comparison 原文）：`success()` / `failure()` / `always()` / `cancelled()` / `format()` / `toJSON()` 等均可用；`==`/`!=`/`&&`/`||`/`!`、上下文插值（`${{ gitea.ref }}`）、字面量当然可用
- `strategy.matrix`（含**动态 matrix**：由 `needs` 输出构建）、`strategy.max-parallel`、`needs`、`if`、`steps` 的 `uses`/`run`/`with`/`env`/`id`、job outputs（`echo "x=y" >> $GITHUB_OUTPUT`）、`timeout-minutes`、`continue-on-error`、`services`、`container`
- 上下文 `github.*` **完全等同** `gitea.*`（官方 FAQ：两者功能一致，推荐 `gitea.*` 以兼容未来 Gitea 专属字段；用 `github.*` 也能正常运行，且能通过 actionlint 检查——见下文校验）
- `actions/checkout@v4` 等第三方 action 直接可用（默认从 github.com 下载，见下文"action 下载"）

## Gitea 专属特性（GitHub 没有）

- **绝对 URL 引用 action**：`uses: https://gitea.com/owner/repo@branch` / `uses: http://你的实例/owner/repo@branch`（GitHub 只认站内 action）
- **action 前缀（28.x）**：`uses: self:owner/repo@v1`（引用**本实例**的仓库/工作流）、`uses: $/.gitea/actions/build`（引用**工作流或复合 action 所在仓库与 commit**，无需先 checkout，区别于 `./`）
- **`uses: builtin:checkout`**：Runner 内置 action，无需下载、无需 job 镜像里有 Node；Runner 5.x 起等价 `actions/checkout`（详见"job 容器镜像与内置 action"）
- **Go 编写的 action**（见官方 Creating Go Actions 博客）
- `schedule` 支持非标准 cron：`@yearly` / `@monthly` / `@weekly` / `@daily` / `@hourly`（GitHub 不支持）

## GitHub 语法在 Gitea 不支持 / 被忽略（重点）

| 项 | Gitea 行为 | 替代方案 |
|----|-----------|---------|
| `jobs.<job_id>.environment`（部署环境） | **忽略** | 用 `if` + 手动映射环境名 |
| 复杂 `runs-on`（`runs-on: {group:, labels:}` 形式） | **始终不支持**该形式 | 28.x 支持：静态字符串、标签数组、字符串表达式（`runs-on: ${{ github.event_name == 'push' && 'ubuntu-latest' \|\| 'self-hosted' }}`）与含表达式的数组（`[linux, "${{ ... }}"]`）；分支/标签判断仍可优先用事件过滤（`tags: ['v*']`） |
| `permissions` 的 GitHub 专属 scope | 不支持 `statuses` / `checks` / `deployments` / `id-token` / `security-events` / `pages`（官方兼容说明列出） | 支持 scope 以官方 token-permissions 文档为准：`contents`（作用于 `code` + `releases`）/ `code` / `releases` / `issues` / `pull-requests` / `actions` / `wiki` / `projects` / `packages`；`contents` 与细粒度 scope（如 `code`/`releases`）同给时**细粒度覆盖**；Gitea 专属（GitHub 无独立 scope）：`code` / `releases` / `wiki` / `projects` |
| Problem Matchers、错误注解 workflow 命令 | 忽略 | 无替代（不影响执行） |
| `GITEA_TOKEN` 发布到包仓库 | 未实现 | 使用 PAT |

## 行为差异（写法相同、表现不同）

- **PR 的 `ref`**：GitHub 是 `refs/pull/:num/merge`（合并预览），Gitea 是 `refs/pull/:num/head`（PR 头部）——用 `github.ref == 'refs/heads/main'` 判断分支在 Gitea PR 上恒为 false，天然免疫 PR 误触发
- **`permissions` 生效规则**：有效权限被仓库/组织设置"钳制"，fork PR 与跨仓库访问进一步受限
- **上下文可用性不检查**：`env` 等上下文可用位置比 GitHub 宽松（GitHub 有限制的写法在 Gitea 也能跑，反向迁移时注意）
- **action 下载源**：非全限定 action（如 `actions/checkout@v4`）默认从 `github.com` 下载脚本；内网实例可配置 `[actions].DEFAULT_ACTIONS_URL = self`（只允许 `github` / `self` 两值），或镜像 action 到本实例后用绝对 URL
- **多标签 `runs-on: [a, b]`**：与 GitHub 一致，job 必须落在**同时具备全部标签**的 runner 上，并使用它匹配到的第一个标签对应的环境（官方 28.x FAQ；旧文档"取第一个匹配即可"的说法已不适用）

## 28.x 编写注意（硬约束，写完先过一遍）

- **每个 job 必须有 `runs-on`**：缺失或为空直接失败，不再回退 `runner.default_image`（Runner 5.0.0 起，对齐 GitHub）；调用 reusable workflow 的 job 豁免
- **job 级 `if:` 在 matrix 展开前求值**，仅可用 `github` / `gitea` / `needs` / `vars` / `inputs` 上下文；依赖 `matrix.*` 的条件要挪到 `strategy.matrix.include`/`exclude` 或 **step 级** `if:`
- **matrix `fail-fast` 默认生效**：一个组合失败会取消其余组合；要全部跑完设 `strategy.fail-fast: false`
- **reusable workflow 访问限制**：公共仓库不能调用私有仓库的 reusable workflow；嵌套调用不能超过调用者的 token 权限（官方 28.0.0 发布说明）
- **无效 workflow 会显式失败**：推送解析失败的 workflow 文件会生成一条带错误的失败 run（不再静默）
- **Runner 需要 Git ≥ 2.34.1**（下载 action / reusable workflow 改走 Git CLI）；用 `builtin:checkout` 的 job 镜像也要有 Git，且能访问并信任 Gitea 证书

## 内置 token 与 CI 回推（实测注意）

- **Gitea 内置 token 不裸注入环境变量**（实测踩坑）：GitHub 的 `GITHUB_TOKEN` 自动出现在 job 环境里；Gitea 的 `GITEA_TOKEN` **只通过 `${{ secrets.GITEA_TOKEN }}` 暴露**——步骤里直接引用裸 `${GITEA_TOKEN}` 得到空值（实测 push 报 `Failed to authenticate user`）。必须显式注入，且**禁止硬编码** `<实例>/<owner>/<repo>`（如 `http://server:3500` / `gitea.yindexiaowu.top:16666/Yin/repo`），一律用 `github.server_url` + `github.repository` 动态拼接（`server_url` 含 `https://`，`git push` 需去协议头）：
  ```yaml
  - run: |
      HOST="${GITEA_SERVER_URL#https://}"
      HOST="${HOST#http://}"
      git push "https://oauth2:${GITEA_TOKEN}@${HOST}/${GITEA_REPOSITORY}.git" HEAD:main
    env:
      GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}
      GITEA_SERVER_URL: ${{ github.server_url }}
      GITEA_REPOSITORY: ${{ github.repository }}
  ```
- **`GITEA_TOKEN` 是内置 token、开箱即用**（官方 token-permissions 文档确认：每个 job 自动获得，`${{ secrets.GITEA_TOKEN }}` 直接可用）——**无需**在仓库 UI 手动配置同名 secret（若手动配了同名 secret 会**覆盖**内置 token）。它的权限由 `permissions`（workflow/job 级）+ 仓库/组织 `Settings → Actions → General` 的默认/最大权限设置共同决定
- **CI 内回推产物**（自动更新类 workflow，零硬编码通用模板）：`git add` 限定产物目录（如 `docs/`）→ `git diff --cached --quiet` 判空则跳过提交（幂等）→ commit → 用 `server_url`+`repository` 动态推。schedule / workflow_dispatch 触发时 checkout 处于 detached HEAD，必须 `git push ... HEAD:main` 显式指定分支：
  ```yaml
  - uses: actions/checkout@v4
  - run: |
      # ... 产物生成到 docs/ ...
      git add docs/
      git diff --cached --quiet && echo "无变更，跳过" && exit 0
      git config user.name "gitea-actions"
      git config user.email "actions@gitea.local"
      git commit -m "chore: update docs"
  - run: |
      HOST="${GITEA_SERVER_URL#https://}"
      HOST="${HOST#http://}"
      git push "https://oauth2:${GITEA_TOKEN}@${HOST}/${GITEA_REPOSITORY}.git" HEAD:main
    env:
      GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}
      GITEA_SERVER_URL: ${{ github.server_url }}
      GITEA_REPOSITORY: ${{ github.repository }}
  ```
- `permissions.contents: write` 足够支持回推（对应 Gitea 的 `code: write`）；实际生效权限还受仓库/组织的 MaxTokenPermissions 设置钳制

## Gitea Release 发布（零硬编码，可直接照抄）

> 禁止硬编码 `http://server:3500` / 固定 `owner/repo`（如 `Yin/opencode-gitea`）。实例地址与仓库名必须由上下文动态获取，否则换实例/换仓库即失效。
> **CHANGELOG 驱动（强制）**：禁止用 `git log PREV_TAG..HEAD` 直拼 Release body 冒充 CHANGELOG（见 `changelog-conventions.md`「糟糕实践」）；`CHANGELOG 是发版的输入`（`ci-cd-practices.md` 标准 CD 全流程 ③），CD 必须从 `CHANGELOG.md` 该版本小节提取。示例仓库需先有 `CHANGELOG.md`（含 `## [Unreleased]`，发版前整理为 `## [x.y.z] - YYYY-MM-DD`）——版本一致性 `tag == CHANGELOG == 包清单版本` 进流水线，不一致即失败（见 `changelog-conventions.md` 一致性卡点；**单一版本源仓**前提，monorepo/多制品按各自版本源）。

- **触发**：`on.push.tags: ['v*']`（打 tag 发版）；`workflow_dispatch` 触发时跳过一致性校验（人工已 gate）
- **`permissions.contents: write`** 足够（兼容 Gitea `releases: write`）
- **动态拼接（零硬编码，推荐）**：`github.server_url` + `github.repository` + `github.ref_name`（`github.*` 完全等同 `gitea.*`，且可过 actionlint；`gitea.*` 会报 `undefined variable "gitea"`）
  ```yaml
  permissions:
    contents: write
  jobs:
    release:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
          with: { fetch-depth: 0, persist-credentials: false }
        - name: Check version consistency
          run: |
            TAG="${{ github.ref_name }}"
            case "$TAG" in v*) ;; *) echo "workflow_dispatch，跳过"; exit 0; esac
            VER="${TAG#v}"
            PKG_VER=$(node -p "require('./package.json').version")
            [ "$VER" != "$PKG_VER" ] && echo "ERROR: tag $TAG != package.json $PKG_VER" >&2 && exit 1
            grep -q "## \[$VER\]" CHANGELOG.md || { echo "ERROR: CHANGELOG.md 缺少 ## [$VER]" >&2; exit 1; }
        - name: Extract Release Notes from CHANGELOG
          env:
            TAG_NAME: ${{ github.ref_name }}
          run: |
            VER="${TAG_NAME#v}"
            VER="$VER" node -e "
              const fs=require('fs'); const ver=process.env.VER;
              const md=fs.readFileSync('CHANGELOG.md','utf8'); const lines=md.split('\n');
              let s=-1,e=lines.length;
              for(let i=0;i<lines.length;i++){
                if(lines[i].startsWith('## ['+ver+']')) s=i;
                else if(s!==-1 && /^## \[/.test(lines[i])){e=i;break;}
              }
              if(s===-1){console.error('未找到 ## ['+ver+']');process.exit(1)}
              const section=lines.slice(s,e).join('\n').trim();
              const body=section+'\n\n---\n\nInstall: \`npx opencode-gitea gitea install\`';
              fs.writeFileSync('/tmp/changelog.txt', body);
            "
        - name: Create Gitea Release
          env:
            GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}
            GITEA_SERVER_URL: ${{ github.server_url }}
            GITEA_REPOSITORY: ${{ github.repository }}
            TAG_NAME: ${{ github.ref_name }}
          run: |
            [ -z "$GITEA_SERVER_URL" ] && echo "ERROR: server_url 为空" >&2 && exit 1
            [ -z "$GITEA_REPOSITORY" ] && echo "ERROR: repository 为空" >&2 && exit 1
            BODY=$(node -e "const fs=require('fs'); const tag=process.env.TAG_NAME; const body=fs.readFileSync('/tmp/changelog.txt','utf8'); console.log(JSON.stringify({tag_name:tag,name:tag,body,draft:false,prerelease:false}))")
            API_URL="$GITEA_SERVER_URL/api/v1/repos/$GITEA_REPOSITORY/releases"
            HTTP_CODE=$(curl -s -o /tmp/resp.json -w "%{http_code}" -X POST -H "Authorization: token $GITEA_TOKEN" -H "Content-Type: application/json" -d "$BODY" "$API_URL" || echo "000")
            cat /tmp/resp.json; echo "HTTP $HTTP_CODE"
            [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "409" ] || { echo "Release 失败 HTTP=$HTTP_CODE" >&2; exit 1; }
  ```
- **API 形态**：`POST {server_url}/api/v1/repos/{owner}/{repo}/releases`，鉴权 `Authorization: token $GITEA_TOKEN`（`GITEA_TOKEN` 须 `env: GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}` 显式注入，不裸注入），payload `{tag_name,name,body,draft,prerelease}`，成功 `201`/`200`，已存在 `409` 幂等视为成功
- **校验**：`github.server_url/repository/ref_name` 均在 `references/contexts.md` 常用属性表已列；用 `github.*` 可直接过 `actionlint`，无需 `-ignore`

## job 容器镜像与内置 action（Runner 5.x）

- 官方 job 镜像：`docker.gitea.com/runner-images:ubuntu-latest`
- **优先 `builtin:checkout`**（Runner 5.x 起等价 `actions/checkout`，且无需下载、无需镜像内有 Node）。常用输入及默认：`fetch-depth`（`1`，`0` 取全史）、**`clean`（`true`，删除未跟踪文件、含子模块）**、`submodules`（`false`；`true`/`recursive`）、`lfs`（`false`）、`persist-credentials`（`true`，凭据仅发往 `github.server_url`、随 job 结束清除）；另支持 `repository`/`ref`/`token`/`path`/`ssh-key`/`ssh-known-hosts`/`ssh-strict`/`ssh-user`/`sparse-checkout`/`sparse-checkout-cone-mode`/`filter`（如 `blob:none`）/`fetch-tags`/`show-progress`/`set-safe-directory`，输出 `ref`/`commit`；**传入未知输入会直接失败该步骤**。分支检出为跟踪 `origin` 的本地分支
- `actions/checkout@v4` 仍可用（从 github.com 或本实例下载）；Git ≥ 2.34.1

## 版本边界（只覆盖 Gitea 28.x + Runner 5.x）

> 能力表为维护者提炼，**以官方文档为准**（docs.gitea.com 右上角可切 28.1 / 29-dev 等版本；Runner 侧见 https://gitea.com/gitea/runner）。

**本技能默认即按 28.x + Runner 5.x 编写**，无需再为旧版本保守降级——标准函数、表达式 `runs-on`、动态 matrix / `max-parallel`、`self:`/`$/`/`builtin:` 均可直接用（能力出自 28.x 官方 comparison / FAQ 与 28.0.0、Runner 5.0.0 发布说明，详见上文各节）。

- **旧版本不在支持范围**：Gitea ≤ 1.27 / Runner ≤ 4.x 的能力差异不再维护，如目标过旧请查该版本官方文档，不要套用本文
- 版本存疑或与官方冲突 → **以官方文档为准**；本文只是速查，不是最终权威（禁止查证只会让技能越用越旧）

### 两个维度：语法看实例版本，执行看 Runner 版本

- **语法能力**（键、事件、表达式函数、runs-on 形式、matrix、permissions scope）由 **Gitea Server 版本**决定——实例负责解析 workflow、求值表达式、展开 matrix/runs-on 并调度 job
- **执行能力**（job 能否跑、action 的 Node 运行时要求、`builtin:*` 与 `checkout` 行为、Git 版本要求）由 **Runner 版本与运行镜像**决定——Runner 与实例**独立发版**，只负责执行层
- 两者不可混为一谈：语法在 28.x 可用 ≠ 任意旧 Runner 都能跑；Runner 5.x 能跑 ≠ 旧实例能解析

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
3. 每个 job 都要写 `runs-on`（28.x + Runner 5.x 起缺失即失败，不再回退默认镜像）；支持静态字符串、标签数组、表达式形式；`{group:, labels:}` 仍不支持
4. 表达式函数直接可用（28.x 支持标准 GitHub 函数）；分支/标签判断仍可优先用事件过滤（`tags: ['v*']`）
5. `permissions` 移除 GitHub 专属 scope（statuses/checks/deployments/id-token/security-events/pages），改用 Gitea 支持 scope（见官方 token-permissions 文档）
6. `GITHUB_TOKEN` 相关操作改用 `GITEA_TOKEN`（**须 `env: GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}` 显式注入，不裸注入**；包发布未实现需 PAT）
7. PR 分支判断依赖 `ref == refs/heads/main` 的写法在 Gitea 天然成立，无需改
8. 内网实例：核对 action 下载源（DEFAULT_ACTIONS_URL / 绝对 URL / 镜像）
9. 自托管 Windows runner：默认 shell 是 bash，加 `defaults: {run: {shell: powershell}}`
10. （可选）优先 `builtin:checkout`（Runner 5.x）；本实例 action 用 `self:`，同仓工作流/复合 action 用 `$/`