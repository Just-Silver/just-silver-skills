## 一键安装/更新

```bash
curl -fsSL https://raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/install-skills.sh | bash
```

Windows 请在 Git Bash（或任意带 bash 的命令窗）中执行；无需先克隆仓库，自动拉取最新版并**平铺**安装到通用 agent 技能目录 `~/.agents/skills/`（Windows 下即 `C:\Users\<你>\.agents\skills\`），每个技能一个直接子目录 `~/.agents/skills/<技能名>/SKILL.md`（技能名取 frontmatter 的 `name`），只扫描一级子目录的客户端也能发现；本仓库技能由清单 `.just-silver-skills.manifest` 与每个目录内的标记 `.jss-skill` 跟踪，安装只覆盖自己的目录，同级的他人技能（find-skills、gh-skill 等）不受影响，幂等可重跑；并顺带清理旧布局目录 `~/.agents/skills/just-silver-skills/` 与 `~/.config/opencode/skills/just-silver-skills/`。

## 一键卸载

```bash
curl -fsSL https://raw.githubusercontent.com/Just-Silver/just-silver-skills/main/scripts/uninstall-skills.sh | bash
```

按清单 + 归属标记只删除本仓库装出来的 `~/.agents/skills/<技能名>/`（同级的他人技能不动；清单项若已被其他工具接管会跳过并提示），并顺带清理旧布局目录与安装/更新异常中断残留的临时目录。

<!-- AUTO-GENERATED: 技能表格由 scripts\update-readme.ps1 生成，请勿手改 -->

| 技能 | 介绍 | 跳转位置 |
|------|------|----------|
| bootstrapblazor | Use when working with BootstrapBlazor (also called BB, bb, or bootstrapblazor) components and needing their... | [skills/bootstrapblazor/](skills/bootstrapblazor/) |
| github-actions | Use when creating or editing GitHub Actions or Gitea Actions workflow YAML (.github/workflows/*.yml, .gitea... | [skills/github-actions/](skills/github-actions/) |
| sdlc / api-and-interface-design | Use when designing module boundaries or public interfaces, when defining error semantics, when adding field... | [skills/sdlc/api-and-interface-design/](skills/sdlc/api-and-interface-design/) |
| sdlc / code-simplification | Use when code works but is harder to read or maintain than it should be, when reviewing for unnecessary com... | [skills/sdlc/code-simplification/](skills/sdlc/code-simplification/) |
| sdlc / constraint-driven-development | Use when no quality bar is written down, when setting up constraints or defining standards, when an agent s... | [skills/sdlc/constraint-driven-development/](skills/sdlc/constraint-driven-development/) |
| sdlc / deprecation-and-migration | Use when removing an old API, feature, or distribution channel, when renaming a public function with downst... | [skills/sdlc/deprecation-and-migration/](skills/sdlc/deprecation-and-migration/) |
| sdlc / documentation-and-adrs | Use when making an architectural decision with alternatives, when asked why something is the way it is and ... | [skills/sdlc/documentation-and-adrs/](skills/sdlc/documentation-and-adrs/) |
| sdlc / doubt-driven-development | Use when stakes are high (production, security, irreversible), when working in unfamiliar code, when correc... | [skills/sdlc/doubt-driven-development/](skills/sdlc/doubt-driven-development/) |
| sdlc / incremental-implementation | Use when implementing any feature or change that touches more than one file, when about to write a large am... | [skills/sdlc/incremental-implementation/](skills/sdlc/incremental-implementation/) |
| sdlc / observability-and-instrumentation | Use when adding logging, metrics, tracing, or alerting, when shipping a feature that runs in production, or... | [skills/sdlc/observability-and-instrumentation/](skills/sdlc/observability-and-instrumentation/) |
| sdlc / security-and-hardening | Use when handling user input, secrets, tokens, or file paths, when building auth or external integrations, ... | [skills/sdlc/security-and-hardening/](skills/sdlc/security-and-hardening/) |
| sdlc / shipping-and-launch | Use when shipping a versioned release with git tag, CHANGELOG, and Release, before pushing tag or publishin... | [skills/sdlc/shipping-and-launch/](skills/sdlc/shipping-and-launch/) |

<!-- /AUTO-GENERATED -->
