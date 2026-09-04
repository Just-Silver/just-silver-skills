---
name: shipping-and-launch
description: Use when shipping a versioned release with git tag, CHANGELOG, and Gitea/GitHub Release, before pushing tag or publishing Release, when verifying tag, CHANGELOG, and package version consistency, or when planning staged rollout and rollback.
---

# Shipping and Launch（版本发布与回滚）

## Overview

不可重复的发布等于没有发布。每次发布必须可验证（tag==CHANGELOG==包版本）、可追溯（Release body 来自 CHANGELOG 对应小节）、可回退（push 前已知回滚路径）。

## When to Use

- 打 `v*` tag、发 Gitea/GitHub Release 前
- 检查一次发版是否合规（tag、CHANGELOG、包版本三处是否一致）
- 定分阶段放量、回滚预案时
- CI 发版链路失败（version consistency / Release body 提取失败）后修复时

**When NOT to use:**

- 日常开发提交（无 tag、无 Release）
- 只改 workflow 语法不涉及发版（用 `github-actions`）
- 纯文档改动无版本变更

## Pre-flight（push tag 前必过）

1. 三处一致：`git tag vX.Y.Z` == `CHANGELOG.md` 顶部 `## [X.Y.Z] - YYYY-MM-DD` == 包版本（`package.json#version` / `*.csproj<Version>` / 等价清单）。不一致即停，不打 tag。
2. CHANGELOG 小节存在且非空：Unreleased 已整理为版本小节，按 Keep a Changelog 分组（Added/Changed/Fixed 等），至少列出 breaking changes。空小节不发版。
3. 产物可构建：本地构建一次通过（如 `dotnet build -c Release` / `npm run build`），单文件产物版本号与 tag 一致。
4. 测试全绿：跑本仓门禁命令全绿后再打 tag。
5. 确认发布面：是否触发批量同步（如 `vars.TARGET_REPOS`）、目标仓库是否会被污染，先确认再 push。

## Release Body 规则

- 必须从 `CHANGELOG.md` 该版本小节截段提取，禁止 `git log` 堆砌。
- tag 触发的 checkout 处于 detached HEAD，回推必须显式 `git push origin HEAD:main`（勿裸 push）。

## Rollout 与 Rollback

```
未 push tag → 本地删 tag 重打
已 push tag / 已建 Release → 先删线上 Release，再删远端 tag，再删本地 tag
已同步到下游仓库 → 下游逐个回退到上一版本并重跑旧版安装器
线上严重 bug → 发 patch 版本（如 vX.Y.Z+1），永不复用旧 tag
```

- Gitea：先删 Release 再 `git push --delete origin vX.Y.Z`。
- CD 附件幂等覆盖：旧版附件从上个 tag 重新构建上传。

## Quick Reference

| 场景 | 动作 |
|------|------|
| 发版前 | 三处一致 + CHANGELOG 小节 + 构建 + 测试 + 发布面确认 |
| Release body | CHANGELOG 小节截段，禁 `git log` |
| 未 push 想反悔 | `git tag -d vX.Y.Z` |
| 已 push 想反悔 | 删 Release → 删远端 tag → 删本地 tag |
| 线上事故 | 发 patch 版，不复用 tag |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "赶时间，CHANGELOG 回头补" | Release body 就是 CHANGELOG 小节，无小节即发空 Release，CD 直接失败，重发至少 30 分钟 |
| "tag 先打，版本文件随后改" | version consistency 硬校验失败，tag 要删掉重打，更慢 |
| "小版本不用回滚预案" | 无预案即出事时无手段；预案是 push 前 1 分钟确认的三行字，不是文档工程 |
| "Release body 用 git log 拼一下就行" | git log 是噪音不是发布说明；下游只认 CHANGELOG，拼 log 属违规分发 |
| "复用旧 tag 省事" | tag 不可变，复用即污染历史；一律发 patch 版 |

## Red Flags — STOP

- CHANGELOG 顶部版本 ≠ tag 版本 ≠ 包版本
- Release body 来自 `git log` 而非 CHANGELOG 小节
- tag 已 push 但无回滚路径（删 Release/删 tag/下游回退任一缺失）
- 批量同步目标未确认即 push tag
- 想复用已发布 tag 号

**以上任一出现 → 停手，回 Pre-flight 修正后再谈发布。**

## Verification

- [ ] `tag == CHANGELOG == 包版本` 三处一致，有证据（命令输出）
- [ ] CHANGELOG 版本小节存在且非空
- [ ] 本地构建产物版本号与 tag 一致
- [ ] 门禁测试全绿
- [ ] Release body 来源是 CHANGELOG 小节
- [ ] 回滚路径已确认（未 push / 已 push / 已同步三档各有动作）
