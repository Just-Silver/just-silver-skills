---
name: documentation-and-adrs
description: Use when making an architectural decision with alternatives, when asked why something is the way it is and no record exists, when code and living docs diverge, or before merging a behavior-changing change without updated docs.
---

# Documentation and ADRs（文档与架构决策记录）

## Overview

代码说是什么，文档说为什么。没有 why 的记录等于没有决策；改了代码不改 living 文档等于制造谎言；重写历史快照等于销毁证据。

## When to Use

- 在多个备选里做架构/选型决策前（工具、目录、协议、分发方式）
- 被问"为什么是这样"而答不上来时
- 改了行为性代码（契约、接口、流程）后，living 文档还是旧的时
- 发版、迁移、废弃等需要后人可追溯的变更

**When NOT to use:**

- 单行修 typo、无行为影响的改动
- 已有 ADR 覆盖且未过期，只是执行
- 历史 specs/plans 快照的日常阅读（只读不改）

## 文档分三类，对号入座

| 类型 | 例子 | 规则 |
|------|------|------|
| ADR（决策记录） | `docs/adr/NNNN-*.md` | 决策当时写，含 Context/Decision/Alternatives/Consequences，编号唯一，只增不改 |
| Living doc（活文档） | `AGENTS.md`、README、契约说明 | 与代码同 PR、同提交更新；代码合了文档必须合 |
| Frozen snapshot（冻结快照） | `docs/**/2026-*-*.md`、已合 plans | 只读不重写；过时只加 `Superseded` 标注或另起一篇，不悄悄改旧文 |
| CHANGELOG | 版本小节 | 只记结论不记推理；推理过程在 ADR |

**判断条件（observable predicate）：**

- 文件路径含日期或已合 PR 号 → 按 frozen 处理
- 文件是 AGENTS.md / README / 契约说明且描述当前行为 → 按 living 处理
- 决策涉及 ≥2 备选或影响 >30 分钟工作量 → 写 ADR

## ADR 模板（REQUIRED 字段，缺一不可）

```markdown
# ADR-NNNN: <标题>

Status: Proposed | Accepted | Superseded(<新编号>)
Date: YYYY-MM-DD
Context: <背景与约束，含版本号/平台等事实>
Decision: <选了什么，精确到文件/命令/版本>
Alternatives: <A/B/C 各一行：做法 + 被否原因>
Consequences: <正/负各至少一条，含回滚点>
```

- Alternatives 至少 2 个（"维持现状"可算一个），每个必须写被否原因，无原因即未决策。
- Consequences 必须含负面（成本/风险/回滚），只写好处即未完成。
- 接受后 Status 改 Accepted；被替代只改 Status 指新编号，不改正文。

## 丢失时的诚实规则

- 无 ADR 且记不清 → 明说"当时没记，原因已丢失"，只陈述当前可验证事实，不脑补备选与权衡。
- 补救是补一条现状 ADR（现状是什么、为什么现在是对的），不是伪造一篇历史 ADR。

## Quick Reference

| 场景 | 动作 |
|------|------|
| 做选型 | 先写 ADR（Context→Alternatives→Decision→Consequences），再写代码 |
| 改了契约/接口 | 同 PR 更新 living doc，否则不合 |
| 旧 spec 过时 | 加 `Superseded` 或另起一篇，不重写旧文 |
| 被问 why | 有 ADR 指 ADR，无 ADR 承认丢失并补现状 ADR |
| 发版 | CHANGELOG 只记结论，推理链 ADR 编号 |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "代码即文档，不用写 ADR" | 代码只说是什么，不说为什么没选 B/C；三个月后新人问 why，代码答不上来 |
| "先写代码，ADR 回头补" | 回头即丢失备选与权衡（RED 基线已验证）；决策当时 10 分钟，事后 1 小时也补不回 |
| "小决策不用记" | 标准是 ≥2 备选或 >30 分钟影响，不是"感觉小"；拿不准就写，ADR 成本低于一次误解 |
| "旧 spec 顺手改一下" | 重写快照即销毁决策可追溯；只加 Superseded，不碰正文 |
| "CHANGELOG 写详细点就行" | CHANGELOG 是结论，ADR 是推理；把推理塞 CHANGELOG 即两边都坏 |

## Red Flags — STOP

- ≥2 备选的决策无 ADR 即写代码
- ADR 无 Alternatives 被否原因或无负面 Consequences
- 行为性改动合了，living doc 没同 PR 更新
- 重写了带日期的旧 spec/plans 正文
- 用"记得好像是因为…"回答 why（脑补历史）

**以上任一出现 → 停手，补 ADR/文档后再合。**

## Verification

- [ ] 本次决策有 ADR 编号，含 Context/Decision/Alternatives/Consequences 四段
- [ ] Alternatives ≥2 且各有被否原因；Consequences 含负面与回滚点
- [ ] Living doc 与代码同 PR 更新（或确认无需更新）
- [ ] Frozen 快照未被重写（过时有 Superseded 或新篇）
- [ ] CHANGELOG 只记结论，推理在 ADR
