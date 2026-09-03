# CHANGELOG 与版本发布规范（CD 发版治理）

> 官方源（Keep a Changelog）：https://keepachangelog.com/zh-CN/1.1.0/
> 官方源（Conventional Commits）：https://www.conventionalcommits.org/zh-hans/v1.0.0/
> 官方源（SemVer）：https://semver.org/lang/zh-CN/
> **定位**：本文件是「CD 发版治理」参考——回答**发版前 CHANGELOG 该怎么维护、版本号怎么定、提交怎么写、与流水线怎么衔接**。与同目录语法/实践文件互补：ci-cd-practices.md 回答"部署动作怎么写"，本文件回答"发版内容如何组织与记录"。
> **方法**：规范的细节以本文件提炼要点为准；写进 workflow 前对照 ci-cd-practices.md 的骨架与 workflow-syntax.md 落实语法。官方规范冲突时以官方原文为准。

## 一、为什么要 CHANGELOG：写给"人"，不是 git 日志堆砌

**核心原则（Keep a Changelog）**：

- **CHANGELOG 是给"人"读的**——用户与开发者想知道版本之间有哪些**显著变动**，不是源码演化的流水账
- **绝对不是 git 日志的堆砌**：git 日志充满合并提交、语焉不详的标题、文档更新等噪音；提交记录源码演化，CHANGELOG 记录**重要变更**
- 每个版本应有**独立入口**、**新版本在前**、**包含发布日期**（ISO 8601 `YYYY-MM-DD`，避免 `2012-06-02` 这类不同地区混淆的格式）
- 应注明是否遵守 SemVer（`The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.`）

### 指导原则速记

| 原则 | 说明 |
|------|------|
| 写给*人*而非机器 | 叙述清晰，避免晦涩技术内部行话 |
| 每版本独立入口 | 一个发布版本 = 一个 `## [x.y.z] - 日期` 小节 |
| 同类改动分组 | 按 Added / Changed / Deprecated / Removed / Fixed / Security 分组 |
| 不同版本分别链接 | 版本标题可链接到 tag diff（GitHub Releases 依赖 tag） |
| 新版本在前，旧版本在后 | 倒序排列 |
| 含每个版本的发布日期 | ISO 8601：`## [1.2.0] - 2024-09-27` |
| 注明 SemVer 遵守 | 文件头部声明遵循语义化版本 |

### 变动类型（官方六类）

| 类型 | 含义 |
|------|------|
| `Added` | 新添加的功能 |
| `Changed` | 对现有功能的变更 |
| `Deprecated` | 已经不建议使用、即将移除的功能 |
| `Removed` | 已经移除的功能 |
| `Fixed` | 对 bug 的修复 |
| `Security` | 对安全性的改进 |

**重要**：即使其他什么都不做，也至少要在 CHANGELOG 中列出 **deprecations、removals 以及其他重大（breaking）变动**——升级者应能清楚（尽管痛苦）地知道哪些部分不再被支持。

### 如何减少维护精力：`## [Unreleased]` 区块

文件**最上方**维护一个 `Unreleased` 区块，记录尚未发布的变更。两个好处：

1. 读者知道未来版本可能有哪些变更
2. **发布时直接把 `Unreleased` 内容移动到新版本的区块**，改标题加日期即可——发布动作因此有明确输入

### 糟糕实践（Bad Practices，来自官方）

| 做法 | 问题 |
|------|------|
| 用 git 日志当 CHANGELOG | 充满噪音，不是给人读的 |
| 无视即将弃用的功能 | 升级者应清楚哪些将不再支持 |
| 易混淆的日期格式 | 用 `YYYY-MM-DD` ISO 格式，避免各地区歧义 |
| **不一致的变更记录** | 只记部分重要变更 = 误导用户以为 CHANGELOG 是唯一事实源。要么都记，要么别开这个头。**一致性 > 完美** |

### 撤下版本（YANKED）

因重大 bug 或安全原因撤下的版本**仍应记录**，在版本标题加醒目标签，方括号便于程序识别：

```markdown
## [0.0.5] - 2014-12-13 [YANKED]
```

## 二、Conventional Commits：让提交可被机器推导版本

**CHANGELOG 的维护成本主要来自"发版时整理变更"**。若提交本身有约定结构，工具/人就能从 `Unreleased` 到当前 tag 的提交里分类汇总。Conventional Commits 是配合此目的的**提交信息约定**，不是 CHANGELOG 本身。

### 提交结构

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

例：`feat(parser): adds ability to parse arrays`

### 提交类型与 semver 对应（核心）

| 提交类型 | 含义 | 对应版本 |
|---------|------|---------|
| `feat` | 新增功能 | MINOR（次要） |
| `fix` | 修复 bug | PATCH（修订） |
| `BREAKING CHANGE`（脚注）或 `!` | 破坏性变更 | **MAJOR（主版本）** |
| `build` / `chore` / `ci` / `docs` / `style` / `refactor` / `perf` / `test` | 其他 | 无隐式影响（除非含 BREAKING CHANGE） |

**要点**：

- `!` 可直接放 `:` 前：`feat!: send an email to the customer`；破坏性变更可以是**任意**类型提交的一部分
- 破坏性变更**必须**标记：要么脚注含大写 `BREAKING CHANGE: <desc>`，要么 `<type>(scope)!:` 前缀
- `BREAKING-CHANGE`（连字符）作为脚注 token 时是 `BREAKING CHANGE` 的**同义词**
- 工具实现应**不区分大小写**解析类型，但 `BREAKING CHANGE` 本身必须大写
- 范围（scope）用圆括号：`fix(parser): ...`，描述某部分代码
- 其他类型不强制，但团队一致性重要——避免每类都加还加不统一

### 为什么用 Conventional Commits（官方动机）

- **自动化生成 CHANGELOG**
- 基于提交类型**自动决定语义化版本变更**
- 向同事、公众传达变化的性质
- 触发构建和部署流程（如 `feat` → 发 minor）
- 结构化提交历史，降低贡献门槛

## 三、SemVer 版本决策

### 版本号格式

```
主版本号.次版本号.修订号   （MAJOR.MINOR.PATCH）

1. 主版本 MAJOR：不兼容的 API 变更
2. 次版本 MINOR：向后兼容的功能性新增
3. 修订 PATCH：向后兼容的问题修正
```

- 对应关系：`fix` → PATCH，`feat` → MINOR，`BREAKING CHANGE` → MAJOR（不论类型）
- **0.x（0.1.0）阶段**：主版本为 0 时任何变更都可能破坏兼容；约定式提交建议按"假设已发布产品"来写提交，此时 `feat` 也可对应发 0.x 的 minor/patch，但进入 1.0.0 前可随时破坏
- 发布后打 tag 格式：仓库惯例用 `v` 前缀（`v1.2.3`）以便 `push.tags: ['v*']` 触发；具体见 ci-cd-practices.md「自动发版」

## 四、与 CD 流水线的集成（CHANGELOG 是发版的输入，不是输出）

**关键认知**：CHANGELOG 是**发版动作之前**要写好的东西，不是发布后自动"补"的文档。它驱动发布内容，而非被发布驱动。

### 发布时的依赖顺序

```
Unreleased 区块持续累积（开发中随手记录）         ← 提交时/合并时顺手写
        │
        ▼
要发版时：把 Unreleased 整理成 [x.y.z] - 日期小节   ← 发版决策（人工或工具）
        │
        ▼
tag 版本号 == CHANGELOG 中该版本号（一致性）        ← 流水线可强制检查
        │
        ▼
打 tag → 发布产物 → Release Notes 引用 CHANGELOG   ← 发布
```

### 一致性卡点（强烈建议进 CD 流水线）

发版时**版本号必须三处一致**：`git tag` / CHANGELOG 顶部版本 / 包管理器版本（`package.json` / `*.csproj` 等）。可在 workflow 里加检查步骤，不一致则失败：

```yaml
# 伪代码骨架：tag 触发时校验版本一致（具体按 ci-cd-practices.md + workflow-syntax.md 落实）
# - 解析 GITHUB_REF 取 tag 版本（v1.2.3 → 1.2.3）
# - grep CHANGELOG.md 顶部 ## [1.2.3]
# - 读取包清单版本字段比对
# 任一不一致 → 失败，阻止发布
```

> 无 tag / 无需 CD 的纯库场景，可在 CI 加轻量检查：发版前必须存在对应 CHANGELOG 条目。

### 工具指针（按需选用，不展开配置；用到时查官方文档）

| 工具 | 定位 | 官方源 |
|------|------|--------|
| git-cliff | 从 Conventional Commits 自动生成 CHANGELOG + 可生成 tag | https://git-cliff.org / https://github.com/orhun/git-cliff |
| release-please | 自动版本 + CHANGELOG + Release PR + 打 tag（GitHub） | https://github.com/googleapis/release-please |
| semantic-release | 自动语义化发版（版本+CHANGELOG+发布），配 commit analyzer | https://semantic-release.gitbook.io |
| changelog 生成库 | `conventional-changelog`（npm）等按 Conventional Commits 生成 | 见各包文档 |

> **工具 ≠ 规范**：工具只在你**遵守提交约定**时才能生成像样的 CHANGELOG。提交乱写，任何工具生成的 CHANGELOG 都是垃圾。先立规范（Conventional Commits + 随手记 Unreleased），再谈自动化。

### 手动维护 vs 自动生成的取舍

| 方案 | 优点 | 缺点 | 适用 |
|------|------|------|------|
| 手动维护 Unreleased | 质量高、面向人、无工具依赖 | 需纪律，易漏 | 项目有维护纪律 / 小团队 |
| git-cliff / release-please 生成 | 省力、与 tag 天然一致 | 依赖提交规范；生成内容偏流水账 | 提交规范执行严格的活跃项目 |

> 现实折中（最常见）：**Conventional Commits 保证可追溯 + 发版前人工整理 Unreleased → 发布小节**。既不像纯 git 日志那样噪音大，也不需全自动工具链。

## 五、Common Mistakes（CHANGELOG 视角）

- **用 git 日志当 CHANGELOG** → 噪音大，不是给人读的；见上「糟糕实践」
- **CHANGELOG 不一致**（只记部分重要变更）→ 用户会误以为 CHANGELOG 是唯一事实源；要么全记要么不记
- **breaking change 不标** → 破坏性变更淹没在日志里，升级用户踩坑；必须列出 deprecations / removals / breaking
- **版本号三处不一致**（tag / CHANGELOG / 包版本）→ 发布后对不上，产物与记录脱节；进流水线强制校验
- **想靠工具自动生成但提交乱写** → 工具输出垃圾；先立 Conventional Commits + Unreleased 纪律，再自动化
- **日期格式混乱** → 一律 ISO `YYYY-MM-DD`
- **发版前才补 CHANGELOG** → 变更早忘了；随手在 Unreleased 记录，发版只是移动整理

## 六、落地检查清单（配合 ci-cd-practices.md 的部署清单使用）

- [ ] 项目有 `CHANGELOG.md`，顶部有 `## [Unreleased]` 区块，声明遵循 Keep a Changelog 与 SemVer
- [ ] 提交遵循 Conventional Commits（或至少有固定类型）；`feat` / `fix` / `BREAKING CHANGE` 分类正确
- [ ] 版本决策清楚：MAJOR / MINOR / PATCH 对应关系明确（0.x 阶段特例已约定）
- [ ] 发版时 tag 版本 == CHANGELOG 该版本 == 包清单版本（三处一致，最好进 CI/CD 强制）
- [ ] CHANGELOG 至少列出 breaking / deprecations / removals；日期用 ISO
- [ ] 明确"手动维护 vs 自动生成"取舍；若用工具，提交规范先立好
