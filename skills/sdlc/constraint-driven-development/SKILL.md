---
name: constraint-driven-development
description: Use when no quality bar is written down, when setting up constraints or defining standards, when an agent silences checks or skips tests to get green, or when you need a coverage or performance threshold and don't know what number to pick.
---

# Constraint-Driven Development（约束驱动开发）

## Overview

spec 说造什么，TDD 证明能跑，约束定义什么算"好到能发"。agent 一下午写的比你一周读的多，判断必须从人脑搬进持续运行的检查：检查要存在，要有你亲定的数字，要离活足够近让 agent 自己修。

## When to Use

- 开新项目/大功能且质量 bar 没写下来时
- 用户说"定约束"、"加质量门"、"别让 agent 交垃圾"时
- agent 为变绿静默关检查、跳测试、删断言、留 stub 时
- 覆盖率/性能数字每次 PR 现吵，需要一次定死时
- 跑无人值守循环（`/build auto` 类）前，唯一的守门员是 agent 自己写的测试时

**When NOT to use:**

- 已有 `CONSTRAINTS.md` 且不改——读它照做
- 一次性脚本、spike、原型
- 现在就要一次 review 或建 CI 流水线（那是别的活）

## Floor（底线，无需配置，永远执行）

- 无新增压制注释：各类 `disable warning` / `ignore error` / `exclude from coverage` / `nolint` / `noqa` / `ts-ignore` / `eslint-disable` 类
- 无未实现 stub：抛 `NotImplemented` 占位、`TODO` 空实现、空 `catch {}`
- 无故跳过/删除测试：删测必须在 commit message 写原因
- 源码无 secrets
- **本文件不许为放行而弱化**：改弱 bar 本身即违规，需单独 review

## 定 bar 四问（每问都有默认答"不知道"也能落）

```
Q1: Floor 之外还要强制哪几项？(a)新代码覆盖率 (b)安全扫描 (c)性能预算 (d)可访问性 (e)架构边界
    猜：(a)+(b)——有测试 runner 且碰用户输入就选它俩。代价：(c)(d)需可运行 URL，(e)需规则文件
Q2: agent 干活中检查挂了，拦还是告警？
    默认：Floor 全拦，其余前两周告警后转拦。无人值守时告警等于无
Q3: 目标数字想好了吗？没有就测现状锁死（Ratchets，见下）
    默认：测现状，只许升不许降
Q4: 最慢能忍多久的检查？
    默认：任务结束 90 秒内，CI 不限
```

超四问即停。十二问 intake 产出没人懂的配置。

## Ratchets（棘轮：测现状锁线）

- 没数字就先测：跑一次套件记覆盖率/体积/耗时，写进"Measured"表，方向只许好不许坏
- 新代码覆盖率默认：变更行 ≥80%（读 lcov 与 git diff 交集，不跑第二遍套件）
- 全局覆盖率：must not fall；体积：must not grow

## CONSTRAINTS.md（一份放仓根，所有 agent 可读）

```markdown
# Constraints

Last reviewed: YYYY-MM-DD by @who

## Floor（永远执行，见本技能 Floor 节）

## Enforced with numbers

| 维度 | 规则 | 检查命令 | 时机 |
|------|------|----------|------|
| 类型 | 零错误 | 本仓构建命令（如 `tsc --noEmit` / `dotnet build` / `go build ./...`，按仓取一） | 每次编辑 |
| 格式 | 零错误 | 本仓格式化校验（如 `prettier --check` / `dotnet format` / `gofmt -l`，按仓取一） | 每次编辑 |
| 测试 | 全绿 | 本仓测试命令（如 `npm test` / `dotnet test` / `go test ./...`，按仓取一） | 任务结束 + CI |
| 覆盖率 | 变更行 ≥80% | 本仓覆盖率采集 + git diff（按仓取一） | 任务结束 + CI |
| secrets | 源码无密钥 | 密钥扫描（如 `gitleaks detect`，按仓取一） | 每次编辑 |
| 依赖 | 无 high+ 漏洞 | 本仓依赖审计（如 `npm audit` / `dotnet list package`，按仓取一） | CI |

每行必须有"检查命令"列。有数字无命令即许愿不是约束。

## Measured, not yet enforced

| 指标 | 今天 | 方向 |
|------|------|------|
| 项目覆盖率 | x% | must not fall |
| 产物大小 | x | must not grow |

## Exceptions（例外需 ID + 到期）

| ID | 规则 | 路径 | 原因 | Owner | 到期 |
|----|------|------|------|-------|------|
| W1 | xxx | `src/legacy/**` | 跟踪号 | @who | YYYY-MM-DD |
```

再在 `AGENTS.md` 加一行：`先读 CONSTRAINTS.md 再写代码；不许弱化它放行。`

## 弱化检测（diff 里出现即告警）

- 新增压制注释（见 Floor）
- 跳过/删除测试无 commit 原因
- 断言被掏空、stub 上线
- 阈值数字被调低（80→70）、维度被删
- CONSTRAINTS.md 本身被改弱

## Quick Reference

| 场景 | 动作 |
|------|------|
| 无 bar 开工 | 先探测现状 → 四问 → 写 CONSTRAINTS.md → AGENTS.md 挂钩 |
| agent 为绿关检查 | 命中 Floor 即拦，修代码不修 bar |
| 没数字 | 测现状锁线，只升不降 |
| 要例外 | 进 Exceptions 表，有 ID + Owner + 到期，无裸例外 |
| 跑无人循环前 | 确认 Floor + 数字 + 命令三全，否则不许跑 |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "关掉这条 lint 先变绿" | 关规则是掩盖信号不是修问题；规则误报走最小范围例外 + 理由 + review，不关全局 |
| "测试后面补" | 后面即永不；赶工砍范围不砍验证，改逻辑必须带测 |
| "这条 bar 太严，先放宽" | 放宽 bar 本身即违规；bar 只许收紧，例外走 Exceptions 表限期 |
| "数字随便定一个" | 编造的数字会被无视；测现状锁线，真实才有约束力 |
| "原型不用 bar" | Floor 仍执行；原型豁免的是数字维度，不是压制/ stub / secrets 三条 |

## Red Flags — STOP

- 新增压制注释无理由
- 跳/删测试无 commit 原因
- stub、空 catch、掏空断言上线
- 阈值被调低、维度被删、CONSTRAINTS.md 被改弱
- 无检查命令的"约束"（许愿条目）
- 例外无 ID / 无 Owner / 无到期

**以上任一出现 → 停手，修代码不修 bar，例外进表后再谈合。**

## Verification

- [ ] CONSTRAINTS.md 在仓根，含 Floor + 数字表（每行有命令）+ Measured + Exceptions
- [ ] AGENTS.md 已挂钩（先读约束再写代码）
- [ ] diff 无弱化信号（压制/跳测/调低阈值）
- [ ] 覆盖率/体积只升不降有证据
- [ ] 例外有 ID + Owner + 到期
