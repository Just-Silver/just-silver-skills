# AGENTS.md — 仓库维护指引

本仓库是一个**技能集仓库**：产物是 `skills/**/SKILL.md`，经 `scripts/install-skills.sh` 一键安装到用户的全局技能目录（默认 `~/.config/opencode/skills/just-silver-skills/`，可用 `JSS_SKILLS_DEST` 覆盖）。本文件面向**在本仓库内改动的人或 Agent（维护者）**——它只在"你正在编辑这个仓库"时被加载；安装到用户侧后，技能逻辑全部由各 `SKILL.md` 承载，与本文件无关。

交流用简体中文；git commit 信息用中文。

## 唯一数据源与产物边界

- **技能 = `skills/**/SKILL.md`**，布局只分两类：
  - **自建技能**：直接放 `skills/<name>/` 顶层（如 `bootstrapblazor`、`github-actions`）。不预套分组层；支持文件（`references/`、`scripts/`、`examples/`）放自己目录内，不散落仓库根。真需要隔离某批技能时再 `git mv` 成 `skills/<group>/<name>/`——安装侧整目录拷贝、技能 ID 取叶目录名，与目录层级无关，所以改层级对用户侧零影响。
  - **上游镜像**：整体放 `skills/<镜像名>/`（如 `obra-superpowers`），由 sync workflow 全量覆盖 → **禁止手动修改**（改了会被下次同步冲掉）；目录内 `.mirror` 标记使其自动排除出 README 自建技能表。
- **`README.md` 是自动生成的产物**：技能表格由 `scripts/update-readme.ps1` 从各技能 frontmatter 生成（AUTO-GENERATED 注释块包裹），**不要手改表格**；块外的安装/卸载文案是手写区，可正常编辑。
- **安装/卸载脚本**：`scripts/install-skills.sh` / `scripts/uninstall-skills.sh`，对外命令见 README 顶部。整目录原子替换到全局 `skills/just-silver-skills/`（Windows 即 `%USERPROFILE%\.config\opencode\skills\just-silver-skills\`），安装/卸载只动这一个目录，不碰同级他人技能。

## 改动流程

### 新增 / 修改 / 删除一个技能

1. 改 `SKILL.md`（含 frontmatter `name` + `description`；`description` 会被截断至 110 字符并转义 `|` 作为 README 表格"介绍"列）
2. 跑 `pwsh ./scripts/update-readme.ps1`（幂等：连续两次字节不变；CI 也会自动跑，但本地先验证）
3. `git diff --exit-code README.md` 确认无多余改动——生成器写 LF、checkout 出 CRLF，本地跑完 `git status` 可能残留"格式脏"，`git checkout -- README.md` 即可
4. 删除技能后**顺手清悬空引用**：搜技能名，把别处"详见 xxx"这类手写指向一并改掉（README 表格会自动收敛，手写引用不会）
5. 提交；push 后 CI 的 `update-readme` 再兜底一次。删除/改名**不需要用户手动卸载**：下次安装按清单自动清理其目录

### 技能内容约束

- 每个技能必须有 frontmatter（name + description）+ 明确行为指令（When to Use / 禁止事项 / 触发边界）
- **`description` 是唯一触发入口，必须写硬触发词**（"before writing implementation code"、"when a build fails" 这类可判定场景）；"风险高时""值得的时候""任何多文件改动"这类软判断在 catalog 竞争里打不过硬触发技能，等于没装——本仓库 2026-09-30 因此整体删除了 sdlc 技能组
- 行为规则写成"默认 + 例外"，避免把个人习惯写成无条件的绝对律令；触发靠 `description` + `When NOT to use` 让模型自行判断，不建硬路由矩阵
- 示例：bootstrapblazor 禁止臆造组件 API，必须 `bb-llms --help` 验证可用性后用 `get/search/list` 查官方文档；bb-llms 未装时只提示用户手动安装，**不得自行 dotnet tool install、不得臆造**

## CI 通用铁律（改 workflow / 脚本前必读）

- **并发**：直接推 main 的 workflow（update-readme / update-actionlint）共用 `concurrency.group: auto-commit-main`（`cancel-in-progress: false`）排队串行——回推类禁用 `true`（会取消还没 push 的运行，丢提交）；定时任务靠共用分组排队，不另找时间错峰。sync-* 推 `sync/*` 分支不直接推 main，用独立分组（`sync-<name>`）。
- **回推前一律 `git pull --rebase`**（排队只保证不同时跑，不保证 base 最新，避免 non-fast-forward）。
- **PowerShell 里判"有没有变更"必须看输出**：`$staged = git diff --cached --name-only` + `[string]::IsNullOrWhiteSpace($staged)`；**别写 `if (git diff --cached --quiet)`**——PowerShell 取的是命令 stdout（为空恒假），分支永不执行，无变更时照样 commit/pull/push 空转并打印"已自动提交并推送"（2026-09-30 已在 update-readme / update-actionlint 修掉，同类写法见 sync-upstream-skills.yml 注释）。
- **防循环链**：`skills/**` 变更 → update-readme → 只提交 `README.md`（不在 `skills/**` 内）→ 终止。改 `update-readme.yml` 时保留 `paths` 过滤。
- **上传 `.github/workflows/` 文件**一律用 git push（REST API 无 Workflows 权限）。
- **新增/修改 schedule 类 workflow 后必须立即 `gh workflow run` 手动冒烟**，不得等调度窗口（路径 bug 曾潜伏到首次手动触发才暴露）。
- **改 `scripts/install-skills.sh` / `uninstall-skills.sh` 必须在 PowerShell 宿主用 `curl ... | bash` 真实验证**（脚本内置 MSYS 路径修正，见脚本内注释）。

### 安装/卸载脚本与 CI 的关系

- **无耦合：改脚本不需要动 workflow**。4 个 workflow 都不引用 `scripts/*.sh`、也不做技能安装；`update-readme.yml` 的 `paths: ['skills/**']` 过滤使"只改 `scripts/` / `README.md` / `AGENTS.md`"的提交不触发任何 CI 运行——设计如此，别当漏配或回归。
- **发布的脚本靠 push main 生效**：README 的 `curl` 从 `raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/*.sh` 取。这类提交不产生 CI 运行记录，**别用"CI 没跑过"判断脚本没生效**（对拉远端与本地字节是否一致即可验证）。
- **脚本没有 CI 兜底**：仓库里唯一无人守门的产物就是这两个 sh（技能有 README 生成器、workflow 有 actionlint）。改完只能人工冒烟，用下面这套隔离冒烟（只动 `%TEMP%`，绝不碰真实 `~/.config/opencode/skills/just-silver-skills`）：
  ```pwsh
  $env:JSS_SKILLS_DEST = "$env:TEMP\jss-smoke\skills\just-silver-skills"
  curl -fsSL https://raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/install-skills.sh | bash
  curl -fsSL https://raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/uninstall-skills.sh | bash
  ```
  验收点：干净目录装→卸后该目录消失、安装幂等可重跑（原子替换，失败回滚旧版）、同级他人技能目录不受影响。

## workflow 职责速查

| workflow | 触发 | 动作 |
|---|---|---|
| `update-readme.yml` | push main 且 `paths: ['skills/**']`（或手动） | 跑脚本 → 只提交 `README.md` |
| `update-actionlint.yml` | 每周一 03:00 UTC + 手动兜底（push 不触发） | 跑 `update-actionlint.ps1` 轮询最新 actionlint → 绿灯自动提交二进制+版本；红灯截停改开 PR；本地 exe 缺失强制重下（A1 自愈） |
| `sync-obra-superpowers.yml` | 每周一 03:00 UTC + 手动 | thin caller，只填 inputs；调可复用模板 `sync-upstream-skills.yml`（`workflow_call`）→ 推 `sync/*` 分支开 PR，review 后手动合并 |

路径注意：actionlint 脚本在 **技能目录** `skills/github-actions/scripts/update-actionlint.ps1`（不是仓库根 `scripts/`）——两处同名 `scripts/` 勿混。

新增上游镜像同步：复制 caller 为 `sync-<name>.yml` → 填 inputs（`dst_dir` 必须 `skills/<name>` 顶层）→ concurrency 用独立分组 `sync-<name>` → 模板自动写 `.mirror` → 立即冒烟。
