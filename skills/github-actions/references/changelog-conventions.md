# CHANGELOG 与版本发布规范

> 官方源（Keep a Changelog）：https://keepachangelog.com/zh-CN/1.1.0/
> 官方源（Conventional Commits）：https://www.conventionalcommits.org/zh-hans/v1.0.0/
> 官方源（SemVer）：https://semver.org/lang/zh-CN/
> 覆盖 CHANGELOG 格式、Conventional Commits、SemVer 与发版一致性。

## CHANGELOG 格式

- 格式遵循 Keep a Changelog，版本遵循 SemVer。
- 新版本在前，每个版本一个 `## [x.y.z] - YYYY-MM-DD` 小节。
- 顶部维护 `## [Unreleased]`；发版时整理为版本小节。
- 分组：`Added` / `Changed` / `Deprecated` / `Removed` / `Fixed` / `Security`。
- 至少列出 deprecations、removals、breaking changes。
- 日期用 ISO `YYYY-MM-DD`。
- 不直接用 git 日志充当 CHANGELOG。
- 撤下的版本保留记录并标 `[YANKED]`：

```markdown
## [0.0.5] - 2014-12-13 [YANKED]
```

## Conventional Commits

格式：

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

| 提交类型 | 版本影响 |
|---------|---------|
| `feat` | MINOR |
| `fix` | PATCH |
| `BREAKING CHANGE` 脚注或 `!` | MAJOR |
| `build` / `chore` / `ci` / `docs` / `style` / `refactor` / `perf` / `test` | 无隐式影响 |

- `!` 放在 `:` 前：`feat!: ...`。
- breaking change 必须是脚注 `BREAKING CHANGE: <desc>` 或 `<type>(scope)!:`。
- 类型解析不区分大小写；`BREAKING CHANGE` 必须大写。
- scope 用圆括号：`fix(parser): ...`。

## SemVer

```
MAJOR.MINOR.PATCH
```

- MAJOR：不兼容变更。
- MINOR：向后兼容的新增。
- PATCH：向后兼容的修复。
- `0.x`：开发阶段，任何变更都可能破坏兼容。
- tag 惯例：`v1.2.3`，配 `push.tags: ['v*']`。

## 预发布

- SemVer：`1.2.0-rc.1` / `1.2.0-beta.2` / `1.2.0-alpha`。
- `+build` 是构建元数据，不是预发布。
- CHANGELOG 与包版本使用同一完整后缀：`## [1.2.0-rc.1]`。
- Release 标 `prerelease: true`；正式版 `x.y.z` 为 `false`。
- 正式版小节汇总自上一稳定版以来的完整变更；rc 小节保留历史。
- 转正用 `PATCH /repos/{owner}/{repo}/releases/{id}` 改 `prerelease`，不重新创建。

## 与 CD 集成

顺序：

```
Unreleased 累积 → 整理为 [x.y.z] - 日期 → 校验 tag/CHANGELOG/包版本 → 打 tag → 构建并发布
```

一致性校验（单一版本源仓）：

- `git tag` 版本 == CHANGELOG 顶部版本 == 包清单版本。
- 预发布连后缀一起比：`v1.2.0-rc.1` ↔ `## [1.2.0-rc.1]` ↔ 包版本 `1.2.0-rc.1`。
- monorepo / 多制品仓按各产物版本源分别校验，不强行统一。

## Common Mistakes

- 用 git 日志当 CHANGELOG。
- CHANGELOG 只记部分重要变更。
- breaking change 未标注。
- tag / CHANGELOG / 包版本不一致。
- 预发布漏写 `-rc.1` 等后缀，或把 `0.x` 当预发布。
- 发版前才补 CHANGELOG。
- 日期格式不统一。

## 检查清单

- [ ] 有 `CHANGELOG.md`，顶部有 `## [Unreleased]`
- [ ] 声明遵循 Keep a Changelog 与 SemVer
- [ ] 提交遵循 Conventional Commits
- [ ] 发版时 tag / CHANGELOG / 包版本一致（单一版本源仓）
- [ ] 预发布后缀一致，Release 标 `prerelease: true`
- [ ] 至少列出 breaking / deprecations / removals
