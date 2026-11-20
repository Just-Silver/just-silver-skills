# Gitea Actions 差异要点（相对 GitHub Actions）

> 官方源：https://docs.gitea.com/usage/actions/（comparison / faq / quickstart / token-permissions / design 页面；右上角可切换目标版本）+ Gitea Runner 仓库文档 https://gitea.com/gitea/runner
> 官方源（Release API）：https://docs.gitea.com/api/operations/repo-create-release/ （创建/编辑字段 `prerelease`）
> 本文件是同一技能内 GitHub references 的 **Gitea 补充差异文件**；GitHub 侧语法详见同目录其余文件。
> **定位**：本文件是维护者提炼的**常见差异速查，不是版本能力的最终权威**；与官方文档冲突时**以官方文档为准**。语法/权限/版本能力存疑时应主动核对 docs.gitea.com 对应版本文档与 Gitea/Runner 发布说明，允许并鼓励 Agent 查证。
> **版本基线（2026-11-20 核对）**：Gitea Server **28.4.0**（2026-11-15 发布）+ Gitea Runner **6.0.0**（2026-11-11 发布）。Gitea 已去掉历史 `1.` 前缀（28.0.0 = 原 1.28.0）。**基线之外的版本（更旧的 28.x / 1.x，或 Runner 5.x）不默认保证**：目标是旧版本时必须查该版本官方文档核验能力，不要套用本文；Runner 5.x 的差异见「job 容器镜像与内置 action」节。

## 第一步：确认目标平台（硬性）

- **GitHub** → 用本目录 GitHub references（workflow-syntax / events / expressions / contexts）
- **Gitea** → 本文件 **必读**；**默认按 Gitea 28.4.0 + Runner 6.0.0 编写**（见"版本基线"）。`github.*` 与 `gitea.*` 等价，推荐 `gitea.*`；**实例版本不同时先确认并改查对应版本文档**，不要臆造高版本能力，也不要假设旧版本支持
- 两平台语法大体相似，但**不存在可依赖的固定兼容比例**；事件、权限、token、并发、执行器差异集中在本文列出的点上，迁移时逐项核对，不能整体照搬

## 基本事实与文件位置

| 项 | GitHub | Gitea |
|----|--------|-------|
| 工作流目录 | `.github/workflows/` | `.gitea/workflows/`（官方推荐；`.github/workflows/` 也识别，仅作迁移回退，两处勿放同一工作流） |
| 文件后缀 | `.yml` / `.yaml` | 同 |
| 是否默认启用 | 开箱即用 | 实例级默认启用 + **仓库级需手动开启**（Settings → Enable Repository Actions） |
| 执行者 | GitHub-hosted / 自托管 runner | 需自建 **Gitea Runner 6.0.0**（act 的硬 fork，官方建议与 Gitea 实例分机部署；Runner 6.0.0 要求 Gitea ≥ 1.26.2） |
| `runs-on` | hosted 镜像或自托管 labels | 标签映射 job 容器镜像（默认官方 `docker.gitea.com/runner-images:*` 系列，见"job 容器镜像"节；注册时可自定义 `label:docker://image` 或 `label:host`） |
| 内置 token | `GITHUB_TOKEN`（自动创建，经 `${{ secrets.GITHUB_TOKEN }}` / `${{ github.token }}` 引用，**不会**自动成为步骤里的 `GITHUB_TOKEN` 环境变量） | `GITEA_TOKEN`（**不裸注入**：仅 `${{ secrets.GITEA_TOKEN }}` 可用，步骤内需显式 env 注入，见下文） |

## 直接可用的语法（官方确认，放心照抄）

- 顶层键 `name` / `run-name` / `on` / `env` / `concurrency` / `defaults` / `jobs` / `permissions` 均支持（官方 quickstart demo 即含 `run-name` 与 `${{ job.status }}`）。`concurrency` 只支持 `group` 与 `cancel-in-progress`，**不支持 `queue`**（见"并发"节）
- 事件语法与 GitHub 兼容：`push`（branches/tags/paths 过滤）、`pull_request`、`workflow_dispatch`、`schedule`、`workflow_call`、`workflow_run`、`release`、`issues` 等；`pull_request` / `pull_request_target` 默认 `opened/reopened/synchronize`，与 GitHub 一致（事件与 activity type 明细见官方 FAQ 表）
- **表达式支持标准 GitHub 函数与上下文**（28.4 官方 comparison 原文）：`success()` / `failure()` / `always()` / `cancelled()` / `format()` / `toJSON()` 等均可用；`==`/`!=`/`&&`/`||`/`!`、上下文插值（`${{ gitea.ref }}`）、字面量当然可用
- `strategy.matrix`（含**动态 matrix**：由 `needs` 输出构建）、`strategy.max-parallel`、`needs`、`if`、`steps` 的 `uses`/`run`/`with`/`env`/`id`、job outputs（`echo "x=y" >> $GITHUB_OUTPUT`）、`timeout-minutes`、`continue-on-error`、`services`、`container`
- 上下文 `github.*` **完全等同** `gitea.*`（官方 FAQ：两者功能一致，推荐 `gitea.*` 以兼容未来 Gitea 专属字段；用 `github.*` 也能正常运行，且能通过 actionlint 检查——见下文校验）
- `actions/checkout@v4` 等第三方 action 直接可用（默认从 github.com 下载，见下文"action 下载"）

## Gitea 专属特性（GitHub 没有）

- **绝对 URL 引用 action**：`uses: https://gitea.com/owner/repo@branch` / `uses: http://你的实例/owner/repo@branch`（GitHub 只认站内 action）
- **action 前缀（28.4）**：`uses: self:owner/repo@v1`（引用**本实例**的仓库/工作流）、`uses: $/.gitea/actions/build`（引用**工作流或复合 action 所在仓库与 commit**，无需先 checkout，区别于 `./`）
- **`uses: builtin:checkout`（仅 Runner 5.x）**：Runner 内置 action，无需下载、无需 job 镜像里有 Node；**Runner 6.0.0 已移除该 action，使用它的步骤会直接失败**。当前基线改用 `actions/checkout`；job 镜像没有 Node 时用 `taiki-e/checkout-action`。Runner 5.x 的兼容细节见"job 容器镜像与内置 action"
- **Go 编写的 action**（见官方 Creating Go Actions 博客）
- `schedule` 支持非标准 cron：`@yearly` / `@monthly` / `@weekly` / `@daily` / `@hourly`（GitHub 不支持）

## GitHub 语法在 Gitea 不支持 / 被忽略（重点）

| 项 | Gitea 行为 | 替代方案 |
|----|-----------|---------|
| `jobs.<job_id>.environment`（部署环境） | **忽略** | 用 `if` + 手动映射环境名 |
| `concurrency.queue`（`single` / `max`） | **不支持**（28.4 无 `queue`；`queue: max` 仍是 open proposal，go-gitea/gitea#39195） | 只写 `group` + `cancel-in-progress`；Gitea 固定为单 pending（等同 GitHub `queue: single`），需要多任务排队时合并 workflow 或自行重试 |
| `workflow_dispatch.inputs.<id>.type: environment` | 无 Environments 概念；28.4 Web 表单只特判 `choice` / `boolean` / `number`，其余按文本框 | Gitea 目标用 `string` / `choice`；门禁用 `if` + 分支保护 |
| 复杂 `runs-on`（`runs-on: {group:, labels:}` 形式） | **始终不支持**该形式 | 28.4 支持：静态字符串、标签数组、字符串表达式（`runs-on: ${{ github.event_name == 'push' && 'ubuntu-latest' \|\| 'self-hosted' }}`）与含表达式的数组（`[linux, "${{ ... }}"]`）；分支/标签判断仍可优先用事件过滤（`tags: ['v*']`） |
| `permissions` 的 GitHub 专属 scope | 不支持 `statuses` / `checks` / `deployments` / `id-token` / `security-events` / `pages`（官方兼容说明列出） | 支持 scope 以官方 token-permissions 文档为准：`contents`（作用于 `code` + `releases`）/ `code` / `releases` / `issues` / `pull-requests` / `actions` / `wiki` / `projects` / `packages`；`contents` 与细粒度 scope（如 `code`/`releases`）同给时**细粒度覆盖**；Gitea 专属（GitHub 无独立 scope）：`code` / `releases` / `wiki` / `projects` |
| Problem Matchers、错误注解 workflow 命令 | 忽略 | 无替代（不影响执行） |
| `GITEA_TOKEN` 发布到包仓库 | 未实现 | 使用 PAT |

## 并发（concurrency）

- Gitea 28.4 支持 workflow 级与 job 级 `concurrency` 的 `group` / `cancel-in-progress`（含表达式），同名 group 跨 workflow 互斥
- **不支持 `queue`**（`single` / `max` 均无；`queue: max` 仍是 open proposal，go-gitea/gitea#39195）。行为等同 GitHub 默认 `queue: single`：running 不被取消，只保留一个 pending，新 pending 替换旧 pending
- Gitea 目标不要写 `queue: max` 期待多 pending；需要多个回推串行时合并 workflow 或自行重试（见 `ci-cd-practices.md`「多 workflow 回推排队」）

## 行为差异（写法相同、表现不同）

- **PR 的 `ref`**：GitHub 是 `refs/pull/:num/merge`（合并预览），Gitea 是 `refs/pull/:num/head`（PR 头部）——用 `github.ref == 'refs/heads/main'` 判断分支在 Gitea PR 上恒为 false，天然免疫 PR 误触发
- **`permissions` 生效规则**：有效权限被仓库/组织设置"钳制"，fork PR 与跨仓库访问进一步受限
- **上下文可用性不检查**：`env` 等上下文可用位置比 GitHub 宽松（GitHub 有限制的写法在 Gitea 也能跑，反向迁移时注意）
- **action 下载源**：非全限定 action（如 `actions/checkout@v4`）默认从 `github.com` 下载脚本；内网实例可配置 `[actions].DEFAULT_ACTIONS_URL = self`（只允许 `github` / `self` 两值），或镜像 action 到本实例后用绝对 URL
- **多标签 `runs-on: [a, b]`**：与 GitHub 一致，job 必须落在**同时具备全部标签**的 runner 上，并使用它匹配到的第一个标签对应的环境（官方 28.4 FAQ；旧文档"取第一个匹配即可"的说法已不适用）

## 28.4 编写注意（硬约束，写完先过一遍）

- **每个 job 必须有 `runs-on`**：缺失或为空直接失败，不再回退 `runner.default_image`（Runner 5.0.0 起，对齐 GitHub）；调用 reusable workflow 的 job 豁免
- **job 级 `if:` 在 matrix 展开前求值**，仅可用 `github` / `gitea` / `needs` / `vars` / `inputs` 上下文；依赖 `matrix.*` 的条件要挪到 `strategy.matrix.include`/`exclude` 或 **step 级** `if:`
- **matrix `fail-fast` 默认生效**：一个组合失败会取消其余组合；要全部跑完设 `strategy.fail-fast: false`
- **reusable workflow 访问限制**：公共仓库不能调用私有仓库的 reusable workflow；嵌套调用不能超过调用者的 token 权限（官方 28.0.0 发布说明）
- **无效 workflow 会显式失败**：推送解析失败的 workflow 文件会生成一条带错误的失败 run（不再静默）
- **Runner 需要 Git ≥ 2.34.1**（下载 action / reusable workflow 改走 Git CLI）；job 镜像也要有 Git，且能访问并信任 Gitea 证书（`actions/checkout` 需要；Runner 5.x 的 `builtin:checkout` 同样需要）

## 内置 token 与 CI 回推（实测注意）

- **两个平台的内置 token 都不会自动注入为同名环境变量**：GitHub 的 `GITHUB_TOKEN` 由 GitHub 自动创建，经 `${{ secrets.GITHUB_TOKEN }}` 或 `${{ github.token }}` 引用；Gitea 的 `GITEA_TOKEN` 只通过 `${{ secrets.GITEA_TOKEN }}` 暴露。步骤里直接引用裸 `${GITHUB_TOKEN}` / `${GITEA_TOKEN}` 都可能得到空值（Gitea 实测 push 报 `Failed to authenticate user`）——**两者都必须显式 `env:` 映射**。Gitea 侧还**禁止硬编码** `<实例>/<owner>/<repo>`（如 `http://server:3500` / `gitea.yindexiaowu.top:16666/Yin/repo`），一律用 `github.server_url` + `github.repository` 动态拼接（`server_url` 含 `https://`，`git push` 需去协议头）：
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
  - id: commit
    run: |
      # ... 产物生成到 docs/ ...
      git add docs/
      if git diff --cached --quiet; then
        echo "changed=false" >> "$GITHUB_OUTPUT"
        echo "无变更，跳过提交与推送"
        exit 0
      fi
      git config user.name "gitea-actions"
      git config user.email "actions@gitea.local"
      git commit -m "chore: update docs"
      echo "changed=true" >> "$GITHUB_OUTPUT"
  - if: steps.commit.outputs.changed == 'true'
    run: |
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
> **CHANGELOG 驱动（强制）**：禁止用 `git log PREV_TAG..HEAD` 直拼 Release body 冒充 CHANGELOG（见 `changelog-conventions.md`「糟糕实践」）；`CHANGELOG 是发版的输入`（`ci-cd-practices.md` 标准 CD 全流程 ③），CD 必须从 `CHANGELOG.md` 该版本小节提取。示例仓库需先有 `CHANGELOG.md`（含 `## [Unreleased]`，发版前整理为 `## [x.y.z] - YYYY-MM-DD`；预发布为 `## [x.y.z-rc.N] - YYYY-MM-DD`）——版本一致性 `tag == CHANGELOG == 包清单版本` 进流水线，不一致即失败（见 `changelog-conventions.md` 一致性卡点；**单一版本源仓**前提，monorepo/多制品按各自版本源）。

- **触发**：`on.push.tags: ['v*']`（打 tag 发版），发版 job 用 `if: startsWith(github.ref, 'refs/tags/v')` 兜底。`workflow_dispatch` 的 ref 是分支，**不能**把分支名当 tag 发布；要手动补发时用原 tag run 的 re-run，或单独定义 `tag` 输入并让校验与发布统一使用该输入。
- **`permissions.contents: write`** 足够（兼容 Gitea `releases: write`）
- **动态拼接（零硬编码，推荐）**：`github.server_url` + `github.repository` + `github.ref_name`（`github.*` 完全等同 `gitea.*`，且可过 actionlint；`gitea.*` 会报 `undefined variable "gitea"`）
  ```yaml
  on:
    push:
      tags: ['v*']

  permissions:
    contents: write
  jobs:
    release:
      if: startsWith(github.ref, 'refs/tags/v')   # 非 tag ref 整个 job 跳过，避免后续发布步骤继续执行
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
          with: { fetch-depth: 0, persist-credentials: false }
        - name: Check version consistency
          env:
            TAG_NAME: ${{ github.ref_name }}
          run: |
            VER="${TAG_NAME#v}"
            PKG_VER=$(node -p "require('./package.json').version")
            [ "$VER" != "$PKG_VER" ] && echo "ERROR: tag $TAG_NAME != package.json $PKG_VER" >&2 && exit 1
            grep -qF "## [$VER]" CHANGELOG.md || { echo "ERROR: CHANGELOG.md 缺少 ## [$VER]" >&2; exit 1; }
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
              fs.writeFileSync('/tmp/changelog.txt', section);
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
            VER="${TAG_NAME#v}"
            if printf '%s' "$VER" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+-'; then PRERELEASE=true; else PRERELEASE=false; fi
            BODY=$(PRERELEASE="$PRERELEASE" node -e "
              const fs=require('fs');
              const tag=process.env.TAG_NAME;
              const body=fs.readFileSync('/tmp/changelog.txt','utf8');
              console.log(JSON.stringify({tag_name:tag,name:tag,body,draft:false,prerelease:process.env.PRERELEASE==='true'}))
            ")
            API_URL="$GITEA_SERVER_URL/api/v1/repos/$GITEA_REPOSITORY/releases"
            HTTP_CODE=$(curl -s -o /tmp/resp.json -w "%{http_code}" -X POST -H "Authorization: token $GITEA_TOKEN" -H "Content-Type: application/json" -d "$BODY" "$API_URL" || echo "000")
            cat /tmp/resp.json; echo "HTTP $HTTP_CODE"
            case "$HTTP_CODE" in
              201|200) echo "已创建 $TAG_NAME（prerelease=$PRERELEASE）" ;;
              409)
                REL_ID=$(curl -s -H "Authorization: token $GITEA_TOKEN" "$API_URL/tags/$TAG_NAME" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>process.stdout.write(String(JSON.parse(s).id)))")
                PATCH_CODE=$(curl -s -o /tmp/patch.json -w "%{http_code}" -X PATCH -H "Authorization: token $GITEA_TOKEN" -H "Content-Type: application/json" -d "{\"prerelease\":$PRERELEASE}" "$API_URL/$REL_ID" || echo "000")
                [ "$PATCH_CODE" = "200" ] || { cat /tmp/patch.json; echo "PATCH 失败 HTTP=$PATCH_CODE" >&2; exit 1; }
                echo "Release 已存在，已校正 prerelease=$PRERELEASE" ;;
              *) echo "Release 失败 HTTP=$HTTP_CODE" >&2; exit 1 ;;
            esac
  ```
- **预发布标记 `prerelease`（按 tag 推导，禁止写死）**：
  - Gitea **不会**根据 tag 名自动判断预发布，`prerelease` 必须显式传布尔值（缺省 `false`）
  - `x.y.z-rc.1` / `-beta.2` / `-alpha` 等 SemVer 预发布 → `true`；`x.y.z` 正式版 → `false`；`0.x` 是开发阶段版本、`+build` 是构建元数据，都不算预发布
  - `draft` 管**可见性**（未发布，外部不可见），`prerelease` 管**成熟度**（已发布但非生产可用）；两者独立，不要用 draft 代替 prerelease
  - `GET .../releases/latest` 只返回**非 draft、非 prerelease** 的最新一条；标记正确后，rc 不会顶掉首页的稳定版
  - 已存在 Release 返回 409 时，改标记要 `PATCH /repos/{owner}/{repo}/releases/{id}`（body `{ "prerelease": true }`）；重新 POST 不会改旧值
  - 实测（Gitea 28.x 系列）：**仓库尚无稳定版时**，创建 rc 后 `/releases/latest` 返回 404；**已有稳定版时**，再发 rc 仍返回该稳定版（实测 `v0.12.0`）；`?pre-release=true` 可筛出 rc；`PATCH {prerelease:false}` 可转正
- **API 形态**：`POST {server_url}/api/v1/repos/{owner}/{repo}/releases`，鉴权 `Authorization: token $GITEA_TOKEN`（`GITEA_TOKEN` 须 `env: GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}` 显式注入，不裸注入），payload `{tag_name,name,body,draft,prerelease}`（`prerelease` 按 tag 推导，见上；勿写死），成功 `201`/`200`；已存在 `409` 时按 tag 查 id 并 `PATCH` 校正 `prerelease`，**不要静默跳过**
- **验证预发布**：创建后 `GET .../releases?pre-release=true` 应包含 rc/beta；`GET .../releases/latest` 在只有预发布时返回 404、有稳定版时仍返回稳定版
- **校验**：`github.server_url/repository/ref_name` 均在 `references/contexts.md` 常用属性表已列；用 `github.*` 可直接过 `actionlint`，无需 `-ignore`

## job 容器镜像与内置 action（Runner 6.0.0，含 5.x 兼容）

- 官方 job 镜像：`docker.gitea.com/runner-images:ubuntu-latest`（Runner 6.0.0 新注册 runner 默认还带 `ubuntu-26.04` 标签）
- **Runner 6.0.0 已移除 `builtin:checkout`**（破坏性变更）：`uses: builtin:checkout` 的步骤会直接失败。新 workflow 用 `actions/checkout`；job 镜像没有 Node 时用 `taiki-e/checkout-action`（只依赖 Git + shell）。Runner 6.0.0 要求 Gitea ≥ 1.26.2，28.4.0 满足
  > docs.gitea.com 的 comparison 页仍把 `builtin:` 列为特性，但 Runner 6.0.0 发布说明（2026-11-11）明确移除 `builtin:checkout`；这里以 Runner 发布说明为准。
- `actions/checkout@v4` 仍可用（从 github.com 或本实例下载；需目标镜像提供 Node 运行时）；Git ≥ 2.34.1。Gitea 示例保留 `@v4` 是保守选择；Runner 6.0.0 发布说明推荐 `actions/checkout@v6`，升级前先核对目标 Runner 镜像的 Node 运行时，不要直接照搬 GitHub 的 `@v7`
- **Runner 5.x 兼容**：5.x 仍支持 `builtin:checkout`（4.0.0 引入，5.0.0 起行为对齐 `actions/checkout`），支持 `fetch-depth`（默认 `1`）、`clean`（默认 `true`，删除未跟踪/忽略文件）、`submodules`、`lfs`、`persist-credentials`（默认 `true`）等常用输入；**传入未知输入会直接失败该步骤**。只在维护旧 Runner 时使用，新 workflow 不要写

## 版本边界（基线：Gitea 28.4.0 + Runner 6.0.0）

> 能力表为维护者提炼，**以官方文档为准**（docs.gitea.com 右上角可切 28.4.0 / 29-dev 等版本；Runner 侧见 https://gitea.com/gitea/runner）。

**本技能按 Gitea 28.4.0 + Runner 6.0.0 编写**：标准函数、表达式 `runs-on`、动态 matrix / `max-parallel`、`self:`/`$/`、`concurrency` 的 `group`/`cancel-in-progress` 可直接用；`builtin:checkout` 只适用于 Runner 5.x（4.0 引入，6.0.0 已移除），`concurrency.queue` 不属于 Gitea（28.4 未实现）。能力出自 28.4 官方 comparison / FAQ 与 28.4.0、Runner 6.0.0 发布说明。

- **基线之外的旧版本**（更旧的 28.x / 1.x、Runner 5.x）差异不默认维护；目标是旧版本时必须查该版本文档，Runner 5.x 见上一节兼容说明
- 版本存疑或与官方冲突 → **以官方文档为准**；本文只是速查，不是最终权威；**允许并鼓励查证**，查到差异应更新本文

### 两个维度：语法看实例版本，执行看 Runner 版本

- **语法能力**（键、事件、表达式函数、runs-on 形式、matrix、permissions scope、`concurrency`）由 **Gitea Server 版本**决定——实例负责解析 workflow、求值表达式、展开 matrix/runs-on 并调度 job
- **执行能力**（job 能否跑、action 的 Node 运行时要求、`builtin:*` 与 `checkout` 行为、Git 版本要求）由 **Runner 版本与运行镜像**决定——Runner 与实例**独立发版**，只负责执行层
- 两者不可混为一谈：语法在 28.4 可用 ≠ 任意旧 Runner 都能跑；Runner 6.x 能跑 ≠ 旧实例能解析

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
# 3) actionlint 1.7.12 尚未认识 concurrency.queue（GitHub 已支持）：
actionlint -ignore 'unexpected key "queue"' .gitea/workflows/ci.yaml
```

> **Windows/pwsh 注意（实测）**：通配符 `*.yml` 不会被 pwsh 展开（见 SKILL.md「校验方法」），**逐个列出文件**或先用 `Get-ChildItem ... *.yml` 展开再传。Linux/macOS bash 下 shell 会自动展开 glob。

- actionlint 版本升级可能引入新规则导致误报，CI 中建议固定版本
- 绝对 URL 的 `uses: https://...` 不会被纯语法检查报错（仅 `actions` 附加规则在执行时检查）
- **actionlint 通过 ≠ Gitea 运行兼容**：它按 GitHub 语法近似校验，不会发现 `queue`、`environment`、`builtin:checkout` 在 Gitea 的被忽略/缺失语义

## 从 GitHub 迁移到 Gitea 的检查清单

1. 目录改为 `.gitea/workflows/`（确认仓库已启用 Actions）
2. 删除 `jobs.*.environment`（被忽略）；`concurrency.queue` 删除（28.4 不支持，保留 `group`/`cancel-in-progress`）；`workflow_dispatch` 的 `type: environment` 改为 `string`/`choice`（无 Environments）
3. 每个 job 都要写 `runs-on`（Runner 5.0.0 起缺失即失败，6.0.0 继续要求；不再回退默认镜像）；支持静态字符串、标签数组、表达式形式；`{group:, labels:}` 仍不支持
4. 表达式函数直接可用（28.4 支持标准 GitHub 函数）；分支/标签判断仍可优先用事件过滤（`tags: ['v*']`）
5. `permissions` 移除 GitHub 专属 scope（statuses/checks/deployments/id-token/security-events/pages），改用 Gitea 支持 scope（见官方 token-permissions 文档）
6. `GITHUB_TOKEN` 相关操作改用 `GITEA_TOKEN`（两个平台的内置 token 都不会自动成为环境变量，须 `env: GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}` 显式注入；包发布未实现需 PAT）
7. PR 分支判断依赖 `ref == refs/heads/main` 的写法在 Gitea 天然成立，无需改
8. 内网实例：核对 action 下载源（DEFAULT_ACTIONS_URL / 绝对 URL / 镜像）
9. 自托管 Windows runner：默认 shell 是 bash，加 `defaults: {run: {shell: powershell}}`
10. Runner 6.0.0：`builtin:checkout` 已移除，改用 `actions/checkout`（镜像无 Node 用 `taiki-e/checkout-action`）；本实例 action 用 `self:`，同仓工作流/复合 action 用 `$/`