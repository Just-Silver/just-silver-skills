# CI/CD 工程实践

> 官方源（GitHub）：https://docs.github.com/en/actions
> 官方源（Gitea）：https://docs.gitea.com/usage/actions/
> 覆盖质量门禁、CI 失败反馈、CI 优化、部署与环境策略；语法细节见同目录语法文件。

## 一、质量门禁

按成本从低到高排列，任一失败即停止合并：

```
lint → type check → unit test → build → integration → E2E → security audit
```

- 每个 PR 都跑，不只跑 main。
- lint / 测试失败就修代码，不用 `eslint-disable`、跳过测试或 rerun 掩盖。
- 含数据库/外部依赖的测试用 job 级 `services` 起容器。

### GitHub 骨架（Node.js）

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: '22'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npx tsc --noEmit
      - run: npm test -- --coverage
      - run: npm run build
      - run: npm audit --audit-level=high
```

其他生态：

| 生态 | Lint / 格式 | 类型 | 测试 | 构建 |
|------|------------|------|------|------|
| Python | `ruff check .` | `mypy .` | `pytest` | `python -m build` |
| Go | `gofmt -l . && go vet ./...` | 编译期 | `go test ./...` | `go build ./...` |
| Rust | `cargo fmt --check && cargo clippy` | 编译期 | `cargo test` | `cargo build --release` |

### 多 workflow 回推排队

多个 workflow 同时 `git push` 回仓库时会因旧 base 冲突。禁止 `cancel-in-progress: true`（会取消尚未 push 的运行）。

GitHub：同一 `group` + `queue: max` + `cancel-in-progress: false`。

```yaml
concurrency:
  group: auto-commit-main
  queue: max
  cancel-in-progress: false
```

- 默认 `queue: single` 只保留一个 pending，新触发会替换旧 pending；需要多个 pending 必须 `queue: max`。
- `queue: max` 最多 100 个 pending，队列满后新运行被取消；FIFO 顺序不保证。
- 同名 `group` 跨 workflow 互斥；group 名大小写不敏感。
- 回推步骤仍要 `git pull --rebase`，并处理 push 失败（重试/告警）。

Gitea：只支持 `group` / `cancel-in-progress`，不支持 `queue`；`cancel-in-progress: false` 仍只保留一个 pending。多个回推来源合并进一个 workflow，或让 push 失败可重试。

## 二、CI 失败处理

| 失败类型 | 动作 |
|---------|------|
| lint | 跑 `lint --fix` 并提交 |
| 类型错误 | 按 `文件:行号` 修类型，不用 `as any` / `# type: ignore` 掩盖 |
| 测试失败 | 先复现，再按根因修复 |
| 构建失败 | 查依赖、lockfile、运行时版本、缺失环境变量 |
| flaky | 查并发/时序/共享状态，不靠 rerun 掩盖 |

## 三、CI 优化

按影响从大到小：

1. 依赖缓存（`setup-*` 的 `cache` / `actions/cache`）
2. 拆分并行 job（lint / typecheck / test / build）
3. `paths` 过滤，docs-only PR 跳过重任务
4. matrix 分片
5. 慢 E2E 移到 `schedule`
6. 更大 runner

## 四、部署与环境

### GitHub Environments

`jobs.<job_id>.environment` 关联环境，可配置 required reviewers、等待计时器、部署分支限制。

- `environment` 写常量字符串：`environment: production`。
- 按输入切换环境时用 `if` 拆 job，各自写固定 `environment`，不要写 `environment: ${{ inputs.xxx }}`。
- Gitea 忽略 `jobs.*.environment`，也没有环境保护规则。

### 手动发布

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
    if: inputs.environment == 'staging'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v7
      - run: ./deploy.sh staging
        env:
          STAGING_TOKEN: ${{ secrets.STAGING_TOKEN }}

  deploy-production:
    if: inputs.environment == 'production'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v7
      - run: ./deploy.sh production
        env:
          PROD_TOKEN: ${{ secrets.PROD_TOKEN }}
```

### 自动发版

```yaml
on:
  push:
    tags: ['v*']
```

tag 触发时 checkout 为 detached HEAD；需回推用 `git push origin HEAD:main`。

### 预发布与正式版

- `prerelease: true`：已发布、外部可见、非生产可用。
- `draft: true`：未发布、外部不可见。
- 由 tag 推导：`v1.2.3-rc.1` / `-beta.2` / `-alpha` → `prerelease: true`；`v1.2.3` → `false`。
- `0.x` 是开发阶段版本，`+build` 是构建元数据，都不是预发布。
- GitHub `make_latest` 不接受 draft/prerelease；Gitea `GET /releases/latest` 只取非 draft、非 prerelease。
- 转正/纠错用 `PATCH /repos/{owner}/{repo}/releases/{id}` 改 `prerelease`；重复创建 Gitea 返回 `409`、GitHub 返回 `422 already_exists`，不会覆盖旧标记。

## 五、双平台速览

| 能力 | GitHub | Gitea |
|------|--------|-------|
| 工作流目录 | `.github/workflows/` | `.gitea/workflows/` |
| 缓存 | setup-* cache / actions/cache | 实例 actions 缓存配置 |
| Environments 保护 | `environment:` + 保护规则 | 不支持，用 `if` + 分支保护 |
| 环境级 secrets | Environments secrets | 仓库/组织 secrets |
| 生产部署门禁 | required reviewers | 手动触发 + 分支保护 |

## Common Mistakes

- 只在 main 上跑检查，PR 不跑。
- flaky 测试靠 rerun 掩盖。
- 生产 secrets 进 CI 或写进仓库。
- 没有手动发布通道，push 直接触发生产部署。
- 把 `concurrency` 当可靠队列：GitHub 默认 `queue: single` 会替换 pending；Gitea 无 `queue`。
- Release body 用 `git log` 而不是 `CHANGELOG.md` 对应小节。
- 预发布 tag 未标 `prerelease: true`，或把 `0.x` 当预发布。

## 检查清单

- [ ] 门禁齐全：lint → type → test → build
- [ ] 每个 PR 都跑，push 到 main 也跑
- [ ] 最小 `permissions`；CI 与生产 secrets 分层
- [ ] 生产部署有手动通道和保护（environment 或分支保护）
- [ ] 回推 workflow 共用同一 `group`，并处理 push 失败
- [ ] 发版校验 `tag == CHANGELOG == 包版本`（单一版本源仓）
- [ ] 预发布 tag 标 `prerelease: true`，正式版为 `false`
- [ ] `actionlint` 通过
