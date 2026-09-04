# CI/CD 工程实践（质量门禁 / CI 失败反馈 / 优化 / 部署）

> 官方源（GitHub）：https://docs.github.com/en/actions （about / using-workflows / deployment 分区）
> 官方源（Gitea）：https://docs.gitea.com/usage/actions/
> **定位**：本文件与同目录语法文件互补——语法文件（workflow-syntax / events / expressions / contexts / gitea-differences）回答"**怎么写才正确**"，本文件回答"**该设计什么、为什么、CI 失败后怎么办**"。两者配合：先用本文件想清楚流水线形状，再用语法文件精确落实每个键。
> **配套文件**：发版时的版本决策 / CHANGELOG / 提交约定见 **`changelog-conventions.md`**（本文件的"CHANGELOG 规范与版本治理"小节给出速览并指向它）。
> **方法**：先读同目录语法文件掌握正确写法；本节示例均按语法文件与 actionlint 校验过的写法编写，可直接照抄骨架。

## 一、质量门禁流水线（Shift-Left）

**核心原则：把检查尽量左移。** lint 阶段抓到的 bug 花几分钟，生产环境抓到的花几小时。门禁应按成本递增排列，越早越便宜：

```
PR / push
    │
    ▼
┌──────────────┐
│  Lint        │  静态检查（最便宜，秒级）
│  Type check  │  类型检查（tsc --noEmit / mypy）
│  Unit test   │  单测（分钟级）
│  Build       │  构建产物可生成
│  Integration │  需 DB / 外部依赖（services）
│  E2E         │  浏览器级（可选、最慢）
│  安全审计     │  npm audit / govulncheck 等
└──────────────┘
    │ 全部通过
    ▼
  可合并
```

- **任何门禁不可跳过**：lint 失败就修，不要 `// eslint-disable` 了事；测试失败就修代码，不要 rerun 掩盖（见 Red Flags）。
- **每个 PR 都跑**，而不是只在 main 跑——main 上的失败已经太晚。
- **每次变更的验证交给 CI**：人肉验证不可重复、不扩展，能自动化就自动化。

### 可照抄骨架（GitHub · Node.js）

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

# 取消同一分支上过时的排队运行（省 runner 分钟）
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read            # 最小权限

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: '22'        # 用受支持的 LTS（2026 建议 22+）
          cache: 'npm'              # 依赖缓存（需提交 package-lock.json）
      - run: npm ci
      - name: Lint
        run: npm run lint
      - name: Type check
        run: npx tsc --noEmit
      - name: Test
        run: npm test -- --coverage
      - name: Build
        run: npm run build
      - name: Security audit
        run: npm audit --audit-level=high
```

其他生态的等价门禁（照此替换 run 步骤即可）：

| 生态 | Lint / 格式 | 类型 | 测试 | 构建 |
|------|------------|------|------|------|
| Python | `ruff check .` | `mypy .` | `pytest` | `python -m build` |
| Go | `gofmt -l . && go vet ./...` | 无（编译期） | `go test ./...` | `go build ./...` |
| Rust | `cargo fmt --check && cargo clippy` | 编译期 | `cargo test` | `cargo build --release` |

> **含数据库/外部依赖的测试**：用 job 级 `services` 起容器（如 postgres，配 health-cmd 等健康检查），测试连接 `localhost:端口`。语法见 workflow-syntax.md。

### 多 workflow 回推排队（防 `git push` 冲突）

多个 workflow 同时带 `git push` 回仓库时（如 update-readme 自动提交 + actionlint 二进制更新 + 镜像同步），会因基于旧 base 提交而 push 冲突失败。此时**不得**用 `cancel-in-progress: true`（会取消掉还没 push 的运行，丢提交），必须让同组排队串行：

```yaml
# 每个带回推的 workflow 顶层都写完全相同的 group
concurrency:
  group: pushback-${{ github.ref }}
  cancel-in-progress: false   # 默认值，可省略；组内排队，一次只跑一个
```

- **同名是关键**：组名按 `group` 字符串跨 workflow 互斥。各 workflow 若 group 名不同（如各用各的 `ci-...`），等于没排队，照样冲突。
- 回推步骤本身仍要 `git pull --rebase` 后再 `git push`（排队只保证不同时跑，不保证 base 最新）。
- CI 纯检查类 workflow 继续用 `cancel-in-progress: true` 省 runner；只有**带写回**（push / Release / 镜像同步提交）的 workflow 进 `pushback-` 组。

### Gitea 等价

同一骨架可直接放到 `.gitea/workflows/`（事件、concurrency、permissions、setup-node 均支持）。注意：Gitea 默认没有 GitHub-hosted runner，`runs-on` 标签映射到 job 容器镜像；`cache: 'npm'` 依赖 Gitea 实例的 actions 缓存配置。语法差异一律以 gitea-differences.md 为准。

## 二、CI 失败反馈循环（与 Agent 协同）

**CI 失败 → 喂回 Agent → 本地修复 → 本地验证 → 重推。** 这是 CI 与 AI Agent 协同时的核心反馈模式——Agent 看不到 GitHub 网页，失败详情必须显式喂给它：

```
CI 失败
    │
    ▼
复制失败输出（job 日志里关键几行：报错消息 + 文件:行号）
    │
    ▼
喂给 Agent（见下方提示模板）
    │
    ▼
Agent 本地修复并在本地跑同一条验证命令
    │
    ▼
本地通过 → push → CI 再跑
```

**提示模板**（把失败详情原样贴进 `<失败输出>`）：

> CI 流水线失败，错误如下：
> [粘贴失败输出]
> 请定位根因并修复，先在本地用与 CI 相同的命令验证通过，再提交推送。

**失败类型 → Agent 动作**：

| CI 失败 | Agent 应做 |
|---------|-----------|
| Lint | 跑 `npm run lint --fix`（或等价）并提交 |
| 类型错误 | 读报错定位 `文件:行号`，修类型（勿 `as any` / `# type: ignore` 掩盖） |
| 测试失败 | 按 systematic-debugging 追根因，先复现再修 |
| 构建失败 | 查依赖/配置（lockfile 漂移、Node 版本、环境变量缺失） |
| 偶发/flaky | **不要 rerun 掩盖**——flaky 背后常藏真 bug，先查并发/时序/共享状态 |

> **REQUIRED SUB-SKILL**：本地修复走 `systematic-debugging`（先复现、找根因再改）；自称"修好了/通过了"前必须本地跑验证命令（`verification-before-completion` 原则：证据先于断言）。

## 三、CI 优化（超过 ~10 分钟时）

按影响从大到小依次尝试，不要一上来就换大 runner：

```
CI 慢？
├── 1. 依赖缓存        setup-* 的 cache 选项 / actions/cache（node_modules、pip、~/.cache/go-build…）
├── 2. 并行拆分 job    lint / typecheck / test / build 拆成独立 job，各自并行
├── 3. 只跑变更        paths 过滤：docs-only PR 跳过 E2E（见 workflow-syntax.md 的 paths 语义）
├── 4. matrix 分片      测试按 Node/OS 矩阵或按目录分片并行
├── 5. 慢测试移出关键路径  大而慢的 E2E 放 schedule 单独跑，PR 只跑快路径
└── 6. 更大 runner      CPU 密集构建换更大 hosted runner / 自托管
```

**路径过滤示例**（docs-only 不触发完整流水线；仅为 `on` 片段，需配齐 `jobs` 才成完整 workflow）：

```yaml
on:
  pull_request:
    paths:
      - 'src/**'
      - 'package.json'
      - 'package-lock.json'
```

**并行拆分示例**：把 lint / typecheck / test 拆成多个无依赖的 job，GitHub 并行跑；测试多的项目再用 `strategy.matrix` 分片（matrix 语法见 workflow-syntax.md）。

## 四、部署与环境策略

### 标准 CD 流水线总览（CI 与 CD 的分界在此）

**术语澄清**：CI 与 CD 都覆盖"自动检查+构建"部分，分界在**谁触发、何时发**。

| | 持续集成 CI | 持续交付 CD | 持续部署 CD |
|---|---|---|---|
| 回答的问题 | 代码**能不能合**？ | 产物**能不能随时发**？ | 要不要**每次自动发**？ |
| 覆盖 | merge 之前：每次 push/PR 自动 lint→type→test→build | merge 之后：构建产物、版本化、发布制品、部署环境 | 在交付之上，**发布动作也自动化** |
| 发布时机 | 不发布 | **手动**触发（生产前有 gate） | 全自动 |
| 典型事件 | `push` / `pull_request` | `workflow_dispatch` / `push tags: ['v*']` | 同左，但不等人 |

> **"持续交付"和"持续部署"缩写都是 CD**，差别只在生产部署是人工 gate 还是自动推。口语"CD"多指 Continuous Delivery。

**标准 CD 全流程**（把 CHANGELOG 放回它应有的位置）：

```
CI 全绿（lint/type/test/build/audit）
   │
   ▼
① 冻结发布内容    合并到 main / release 分支，所有 PR 合入
   │
   ▼
② 版本决策        v1.2.3：按 Conventional Commits 推导 或 手动定（semver）
   │
   ▼
③ 更新 CHANGELOG  ★ 发版的输入：Unreleased → [x.y.z] - 日期，见 changelog-conventions.md
   │
   ▼
④ 一致性校验      tag 版本 == CHANGELOG 版本 == 包清单版本
   │
   ▼
⑤ 打 tag + 发版    git tag v1.2.3；构建产物 + 校验和；发布制品库 / GitHub Releases
   │
   ▼
⑥ 部署 staging     自动，跑冒烟验证
   │
   ▼
⑦ 部署 production  Continuous Delivery：人工 gate（environment required reviewers）
   │                Continuous Deployment：自动推
   ▼
⑧ 可回退          发布记录即版本记录；出问题 rollback 到上一 tag
```

### 环境分层与 Secrets 分层

```
.env.example      → 提交（模板，无真实密钥）
.env              → 不提交（本地开发）
.env.test         → 可提交（测试环境，无真实密钥）
CI secrets        → GitHub/Gitea Secrets（仅 CI 需要的最小集）
生产 secrets      → 部署平台 / 密钥管理，不进 CI
```

- **CI 永远不该持有生产 secrets**。测试/CI 用独立 secrets。
- 分层最小化泄露面：即便 CI 被攻破，也拿不到生产凭据。

### GitHub Environments（环境保护）

`jobs.<job_id>.environment` 让 job 关联一个"环境"，可叠加**保护规则**（在 Settings → Environments 配置）：

- **Required reviewers**：部署到 production 需人工批准
- **等待计时器**：批准后延迟执行（留手动中止窗口）
- **部署分支限制**：只允许 main 等特定分支部署

> **陷阱**：`environment` 键值写**常量字符串**最稳（`environment: production`）。官方 context 可用性表允许表达式，但动态 environment 名在部分场景有注册不可靠的已知问题——要按输入切换环境时，用 `if` 拆多个 job、各自写固定 environment（见下例），不要写 `environment: ${{ inputs.xxx }}`。
> **Gitea 注意**：Gitea **不支持** `jobs.*.environment`（被忽略），也没有 Environments 保护规则概念。Gitea 的"部署门禁"用：手动 `workflow_dispatch` + `if` 分支/输入判断 + 仓库分支保护（见 gitea-differences.md）。

### 手动发布到生产（推荐，配 workflow_dispatch）

手动触发 + environment 门禁是**最稳的发布通道**：不会因 push 误触发生产部署，且可叠环境保护规则：

```yaml
name: Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: '部署目标'
        required: true
        type: choice
        options: [staging, production]

permissions:
  contents: read

jobs:
  deploy-staging:
    if: inputs.environment == 'staging'      # 按输入拆 job，各自 environment 为常量
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v7
      - name: Deploy to staging
        run: ./deploy.sh staging
        env:
          STAGING_TOKEN: ${{ secrets.STAGING_TOKEN }}   # 环境级 secret

  deploy-production:
    if: inputs.environment == 'production'
    runs-on: ubuntu-latest
    environment: production                   # 可配 required reviewers / 分支限制
    steps:
      - uses: actions/checkout@v7
      - name: Deploy to production
        run: ./deploy.sh production
        env:
          PROD_TOKEN: ${{ secrets.PROD_TOKEN }}         # 环境级 secret，只在该环境可用
```

### 自动发版（打 tag 触发）

```yaml
on:
  push:
    tags: ['v*']      # 打 tag 自动发布（比 release 事件更简单直接）
```

> **注意**：tag 触发时 checkout 处于 detached HEAD；若需回推必须 `git push origin HEAD:main`（详见 workflow-syntax.md 陷阱节）。
> **Gitea 等价**：同样用 `push.tags` 或 `workflow_dispatch`；无 environment 门禁，用仓库分支保护 + 手动触发兜底。

### CHANGELOG 规范与版本治理（发版前必读）

**速览**；完整规范见 **`references/changelog-conventions.md`**（Keep a Changelog 格式 + Conventional Commits + SemVer + 与流水线集成）。

- **CHANGELOG 是发版的输入，不是输出**：`## [Unreleased]` 区块随开发持续累积，发版时把它整理成 `## [x.y.z] - 日期` 小节。CHANGELOG 驱动发布内容，而非发布后才补。
- **Keep a Changelog**：`Added` / `Changed` / `Deprecated` / `Removed` / `Fixed` / `Security` 六类分组；**至少**列出 deprecations / removals / breaking changes；日期用 ISO `YYYY-MM-DD`；绝不用 git 日志堆砌。
- **Conventional Commits**：`feat` → MINOR、`fix` → PATCH、`BREAKING CHANGE` / `!` → MAJOR。提交规范是自动生成 CHANGELOG 与自动推导版本的前提。
- **版本一致性（发版硬性卡点）**：`git tag` 版本 == CHANGELOG 顶部版本 == 包清单版本（`package.json` / `*.csproj` 等），三处必须一致。建议进 CD 流水线做检查步骤，不一致即失败。

### Gitea CD 可照抄模板（CHANGELOG 驱动）

> 对应 `changelog-conventions.md` 一致性卡点；禁止 `git log` 拼 body。

见 `gitea-differences.md` 更新后的 `Gitea Release 发布` 骨架（`Check version consistency` + `Extract Release Notes from CHANGELOG`），直接照抄两步即可；`workflow_dispatch` 触发时跳过校验。

## 五、双平台速览（本文件方法论在 Gitea 的对应）

| 工程实践 | GitHub | Gitea |
|---------|--------|-------|
| 质量门禁骨架 | `.github/workflows/ci.yml` | `.gitea/workflows/ci.yml`（事件/语法通用） |
| 缓存 | setup-* cache / actions/cache | 依赖实例 actions 缓存配置 |
| Environments 保护 | `environment:` + 保护规则 | **不支持**，用 if + 分支保护 |
| 环境级 secrets | Environments secrets | 仓库/组织 secrets（无环境级） |
| 手动发布 | `workflow_dispatch` + inputs | 同（语法兼容） |
| 生产部署门禁 | environment required reviewers | 手动触发 + 分支保护 + 人工点按 |

## Common Mistakes（工程视角）

语法层面的坑见 SKILL.md 主文件；以下是**工程/设计层面**的坑：

- **只在 main 上跑检查** → CI 的意义在于 merge 前拦截；每个 PR 都要跑
- **flaky 测试靠 rerun 掩盖** → 掩盖的是真 bug 或真实环境问题，最后爆在发布后
- **CI 从不失败 / 失败被忽略** → 门禁形同虚设；CI 绿了才是合并前提
- **生产 secrets 进 CI / 写进仓库** → CI 与生产 secret 必须分层
- **没有手动发布通道**（只能靠 push 触发部署）→ 生产部署无法控制时机；加 workflow_dispatch
- **生产部署无保护** → GitHub 用 environment 保护规则；Gitea 用分支保护 + 手动触发
- **发版不看 CHANGELOG / 版本一致性** → tag、CHANGELOG、包版本三处不一致，产物与记录脱节；发版前整理 Unreleased 并核对一致性（见 changelog-conventions.md）
- **CD 用 `git log` 拼 Release body 而非 CHANGELOG 该小节** → 违反 `changelog-conventions.md` 糟糕实践；Release 必须引用 CHANGELOG，`git log` 堆砌是噪音
- **无视 CI 优化** → 流水线 10 分钟+ 且无任何优化动作，每次迭代都在烧时间
- **把"能跑"当"设计对了"** → 语法正确只是底线；门禁完整、失败能反馈、发布可回退才是目标

## Red Flags（工程视角）

- 项目没有 CI 流水线（或从没跑绿过）
- CI 失败被 `continue-on-error` / 注释测试 / 跳过步骤掩盖
- lint/type/test 门禁缺失（只 build 不测）
- 生产 secrets 出现在 workflow 文件或普通仓库变量里
- 任何 push 都会触发生产部署、无法手动控制
- 测试 flaky 时第一反应是 rerun 而不是排查
- 打 tag 发版但 CHANGELOG 没有对应版本条目 / 版本号与 tag 对不上

**以上任一出现 → 回到本文件对应章节修正后再谈合并。**

## 落地检查清单（写完 workflow 后逐项过）

- [ ] 门禁齐全：lint → type → test → build（按生态取舍）
- [ ] 每个 PR 都跑，push 到 main 也跑
- [ ] 最小 `permissions`；secrets 分层（CI 无生产凭据）
- [ ] CI 失败会有人（人或 Agent）收到并修复，不靠 rerun 掩盖
- [ ] 生产部署有手动/受控通道 + 保护（environment 或分支保护）
- [ ] 发版流程含 CHANGELOG：Unreleased → 版本小节；tag/CHANGELOG/包版本三处一致（详见 changelog-conventions.md 落地清单）
- [ ] 流水线 ~10 分钟内；超时已做缓存 / 并行 / 路径过滤
- [ ] `actionlint` 校验通过（用法见 SKILL.md「校验方法」）
