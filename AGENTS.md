# AGENTS.md

个人自建的 OpenCode 技能集仓库：`skills/<name>/SKILL.md` 或分组 `skills/<group>/<name>/SKILL.md` 是唯一数据源。
交流用简体中文；git commit 信息用中文。

## 目录结构

- 顶层技能：`skills/bootstrapblazor/`、`skills/github-actions/`、`skills/karpathy-guidelines/`（历史原因保留在顶层，不动；**新建技能不放顶层**）
- 分组技能：`skills/sdlc/<name>/`（**后续新建的规范类技能一律放这里**）
- 镜像目录：`skills/obra-superpowers/`（上游 obra/superpowers 全量镜像，由 sync workflow 自动维护，**不手动改**；靠目录内 `.mirror` 标记自动排除出 README 自建技能表）

## README.md 是自动生成的产物

- 技能表格由 `scripts/update-readme.ps1` 从各技能 frontmatter 生成（AUTO-GENERATED 注释块包裹）——**不要手动改表格**，会被下次运行覆盖
- 新增/修改技能：只改 `SKILL.md`，然后运行 `./scripts/update-readme.ps1`（或直接 push，CI 自动生成）
- frontmatter 必须含 `name` + `description`；`description` 截断至 110 字符（107 + `...`）并转义 `|` 后作为表格"介绍"列
- 脚本幂等：连续运行两次 README 字节不变；缺 AUTO-GENERATED 标记块时脚本报错
- 本地验证：改技能后跑 `pwsh ./scripts/update-readme.ps1`，再 `git diff --exit-code README.md` 确认无多余改动；CI 全跑 Windows runner + pwsh，本地也用 pwsh 验证

## CI 通用铁律（改前先读本节）

- 并发：直接推 main 的 workflow（update-readme / update-actionlint）共用 `concurrency.group: auto-commit-main`（`cancel-in-progress: false`）排队串行——回推类 workflow 禁用 `true`（会取消还没 push 的运行，丢提交）；定时任务不要另找时间错峰，靠共用分组排队；sync-* 推的是 `sync/*` 分支、不直接推 main，用独立分组（`sync-<name>`），不共用此分组
- 回推前一律 `git pull --rebase`（排队只保证不同时跑，不保证 base 最新，避免 non-fast-forward）
- 防循环链：`skills/**` 变更 → update-readme → 只提交 `README.md`（不在 `skills/**` 内）→ 终止；**改 update-readme.yml 时保留 `paths` 过滤**
- 上传 `.github/workflows/` 文件一律用 git push（REST API 无 Workflows 权限）
- 新增/修改 schedule 类 workflow 后必须立即 `gh workflow run` 手动冒烟一次，不得等调度窗口（路径 bug 曾潜伏到首次手动触发才暴露）

## 各 workflow 职责

- `update-readme.yml`：push 到 main 且匹配 `paths: ['skills/**']`（或手动）→ 跑脚本 → 只提交 `README.md`
- `update-actionlint.yml`：每周一 03:00 UTC + 手动兜底（**push 不触发**）→ 轮询 rhysd/actionlint → 有新版提交 `actionlint.exe` + `actionlint.version`；**只有无更新才静默，拉取失败必须抛错染红**
- 路径坑：actionlint 脚本在**技能目录** `skills/github-actions/scripts/update-actionlint.ps1`，**不在仓库根 `scripts/`**（后者与技能目录无关）——两个 workflow 的调用路径不同，别搞混（曾因此踩坑）
- 一键安装/卸载：脚本在 `scripts/install-skills.sh` / `scripts/uninstall-skills.sh`，命令见 README 顶部；安装远程拉 main.tar.gz → 原子替换全局 `skills/just-silver-skills/`，幂等可重跑。两脚本内置 MSYS 路径修正（PowerShell 里 `curl | bash` 时 bash 继承 Windows PATH，需前置 `/usr/bin` 并把 `$DEST` 经 cygpath 转 Unix 路径，否则 `find`/glob 会踩 Windows 工具）——**改这两个脚本必须在 PowerShell 宿主用 `curl ... | bash` 真实验证**（参考脚本内注释）
- `sync-obra-superpowers.yml`：thin caller，只填 6 个 inputs；同步逻辑在可复用模板 `sync-upstream-skills.yml`（`workflow_call`，不独立运行）；模板推固定分支（`sync/<name>`）开 PR，review 后手动合并；前置要求仓库 Settings → Actions → General 勾选 Allow GitHub Actions to create and approve pull requests
- **新增上游同步**：复制 caller 为 `sync-<name>.yml` → 改 inputs（`dst_dir` 必须 `skills/<name>` 顶层）→ concurrency 用独立分组 `sync-<name>` → 模板自动写 `.mirror` 标记（无需改脚本）→ 立即冒烟

## 技能内容约束（bootstrapblazor 示例）

- 每个技能必须有 frontmatter（name + description）+ 明确的行为指令（When to Use / 禁止事项）
- bootstrapblazor：禁止臆造组件 API，必须 `bb-llms --help` 验证可用性后用 `get/search/list` 查官方文档；bb-llms 未装时只提示用户手动安装，**不得自行 dotnet tool install、不得臆造**
