# AGENTS.md — 仓库维护指引

本仓库是一个 **OpenCode 技能集仓库**：产物是 `skills/**/SKILL.md`，经 `scripts/install-skills.sh` 一键安装到用户的全局技能目录。本文件面向**在本仓库内改动的人或 Agent（维护者）**——它只在"你正在编辑这个仓库"时被加载；安装到用户侧后，技能逻辑全部由各 `SKILL.md` 承载，与本文件无关。

交流用简体中文；git commit 信息用中文。

## 唯一数据源与产物边界

- **技能 = `skills/**/SKILL.md`**：技能按**主题归类**——
  - 规范/流程类技能（SDLC 族：增量实现、安全、发版、质疑驱动……）→ `skills/sdlc/<name>/`
  - 独立主题技能（技术栈、行为准则、CI/CD……）→ 直接放 `skills/<name>/` 顶层
  - 不以"单文件还是多文件"判别：单文件技能可直接放顶层，扩出 `references/` / `scripts/` 等支持文件也都在自己目录内；同主题真攒到多个技能时再 `git mv` 成 `skills/<group>/<name>/`（成本低、可逆）
  - 配套支持文件（references/、scripts/、examples/ 等）放所属技能目录内，不散落仓库根
- **`README.md` 是自动生成的产物**：技能表格由 `scripts/update-readme.ps1` 从各技能 frontmatter 生成（AUTO-GENERATED 注释块包裹），**不要手改表格**。
- **`skills/obra-superpowers/` 是上游镜像**：由 sync workflow 全量覆盖，**禁止手动修改**（改了会被下次同步冲掉）。目录内 `.mirror` 标记使其自动排除出 README 自建技能表。
- **安装/卸载脚本**：`scripts/install-skills.sh` / `scripts/uninstall-skills.sh`，对外命令见 README 顶部。

## 改动流程

### 新增 / 修改一个技能

1. 只改 `SKILL.md`（含 frontmatter `name` + `description`；`description` 会被截断至 110 字符并转义 `|` 作为 README 表格"介绍"列——写清楚触发场景）
2. 跑 `pwsh ./scripts/update-readme.ps1`（幂等：连续两次字节不变；CI 也会自动跑，但本地先验证）
3. `git diff --exit-code README.md` 确认无多余改动
4. 提交；push 后 CI 的 `update-readme` 会再兜底一次

> 新建技能按**主题归类**：规范/流程类进 `skills/sdlc/<name>/`；独立主题（技术栈 / 行为准则 / CI/CD 等）直接放 `skills/<name>/` 顶层，不必为"将来可能扩展"预套分组层——技能在自己目录内即可扩展，同主题攒到多个再成组。

### 技能内容约束

- 每个技能必须有 frontmatter（name + description）+ 明确行为指令（When to Use / 禁止事项 / 触发边界）
- 行为规则写成"默认 + 例外"，避免把个人习惯写成无条件的绝对律令；触发靠 `description` + `When NOT to use` 让模型自行判断，不建硬路由矩阵
- 示例：bootstrapblazor 禁止臆造组件 API，必须 `bb-llms --help` 验证可用性后用 `get/search/list` 查官方文档；bb-llms 未装时只提示用户手动安装，**不得自行 dotnet tool install、不得臆造**

## CI 通用铁律（改 workflow / 脚本前必读）

- **并发**：直接推 main 的 workflow（update-readme / update-actionlint）共用 `concurrency.group: auto-commit-main`（`cancel-in-progress: false`）排队串行——回推类禁用 `true`（会取消还没 push 的运行，丢提交）；定时任务靠共用分组排队，不另找时间错峰。sync-* 推 `sync/*` 分支不直接推 main，用独立分组（`sync-<name>`）。
- **回推前一律 `git pull --rebase`**（排队只保证不同时跑，不保证 base 最新，避免 non-fast-forward）。
- **防循环链**：`skills/**` 变更 → update-readme → 只提交 `README.md`（不在 `skills/**` 内）→ 终止。改 `update-readme.yml` 时保留 `paths` 过滤。
- **上传 `.github/workflows/` 文件**一律用 git push（REST API 无 Workflows 权限）。
- **新增/修改 schedule 类 workflow 后必须立即 `gh workflow run` 手动冒烟**，不得等调度窗口（路径 bug 曾潜伏到首次手动触发才暴露）。
- **改 `scripts/install-skills.sh` / `uninstall-skills.sh` 必须在 PowerShell 宿主用 `curl ... | bash` 真实验证**（脚本内置 MSYS 路径修正，见脚本内注释）。

## workflow 职责速查

| workflow | 触发 | 动作 |
|---|---|---|
| `update-readme.yml` | push main 且 `paths: ['skills/**']`（或手动） | 跑脚本 → 只提交 `README.md` |
| `update-actionlint.yml` | 每周一 03:00 UTC + 手动兜底（push 不触发） | 跑 `update-actionlint.ps1` 轮询最新 actionlint → 绿灯自动提交二进制+版本；红灯截停改开 PR；本地 exe 缺失强制重下（A1 自愈） |
| `sync-obra-superpowers.yml` | 每周一 03:00 UTC + 手动 | thin caller，只填 inputs；调可复用模板 `sync-upstream-skills.yml`（`workflow_call`）→ 推 `sync/*` 分支开 PR，review 后手动合并 |
| `sync-drawio-skill.yml` | 每周一 03:00 UTC + 手动 | thin caller，只填 inputs；调可复用模板 `sync-upstream-skills.yml`（`workflow_call`）→ 推 `sync/*` 分支开 PR，review 后手动合并 |

路径注意：actionlint 脚本在 **技能目录** `skills/github-actions/scripts/update-actionlint.ps1`（不是仓库根 `scripts/`）——两处同名 `scripts/` 勿混。

新增上游镜像同步：复制 caller 为 `sync-<name>.yml` → 填 inputs（`dst_dir` 必须 `skills/<name>` 顶层）→ concurrency 用独立分组 `sync-<name>` → 模板自动写 `.mirror` → 立即冒烟。
