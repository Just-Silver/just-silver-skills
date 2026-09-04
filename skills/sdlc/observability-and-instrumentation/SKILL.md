---
name: observability-and-instrumentation
description: Use when adding logging, metrics, tracing, or alerting, when shipping a feature that runs in production, or when a production issue can't be diagnosed from available data.
---

# Observability and Instrumentation（可观测与埋点）

## Overview

看不见的代码运维不了。可观测是能从外部回答"系统在干什么、为什么"；埋点不是上线后补的，是跟功能一起写的，跟测试一样。无埋点上线，第一个用户报障即考古。

## When to Use

- 写任何跑在生产的功能（服务、endpoint、job、外部集成）时
- 线上事故定位太慢（"看不出发生了什么"）后补埋点时
- 定/审告警规则时
- PR 加了 I/O、重试、队列、跨服务调用时

**When NOT to use:**

- 正在救火——先修，埋点是让下次快的（调试另有流程）
- 压测调优（那是性能优化的活）
- 发版日 checklist 与回滚线（见 `shipping-and-launch`，本技能供弹药）

## 先定义"正常"再埋点

无问题的埋点即噪音。动码前写下值班会问的 2-4 个问题，每个信号必须回答其中之一：

```
功能：gitea-agent 处理 issue 评论触发
值班会问：
1. 触发成功率多少？哪步失败最多？
2. 失败时卡在哪段？（收 webhook / 解析 / 调 API / 回评论）
3. Gitea API 是不是比平时慢？
```

答不上问题即不配埋点——先想清再动手。

## 三信号选型

| 信号 | 回答 | 成本 | 例子 |
|------|------|------|------|
| 结构化日志 | 这个个案发生了什么 | 随流量 | `trigger_failed` 带 step + errorCode |
| 指标 | 多快/多少，聚合态 | 每序列固定，便宜 | 外部调用 p99 |
| Trace | 时间花在哪段 | 随请求，常采样 | 一次慢触发按段拆解 |

口诀：指标说**有没有事**，trace 说**哪段的事**，日志说**为什么**。

## 结构化日志

记事件不记散文。每行 JSON，稳定事件名 + 机器可读字段：

```json
{"ts":"...","level":"warn","event":"trigger_failed","run_id":"...","repo":"o/r","issue":123,"step":"post_comment","errorCode":"..."}
```

- 级别：`error`（ invariant 破了，有人得看）/ `warn`（降级但处理了）/ `info`（业务大事）/ `debug`（默认生产关）
- **关联 ID 必带**：入口生成（复用 `X-Request-ID` 或造），每行日志/span/外部调用全带，无 ID 即散沙
- **禁打 secrets/token/密码/完整 PII**，字段白名单，不打整个 body（大 body 只记长度/摘要）
- 失败只记一次：带 `step + err.stack + exitCode`，不层层刷屏；成功/失败最后一条总结行

## 指标（RED/USE）

- 请求型：每个 endpoint + 每个外部依赖上 RED——**R**ate（qps）、**E**rrors（失败率）、**D**uration（直方图，不看平均，看 p50/p95/p99）
- 资源型：队列/池/主机上 USE——**U**tilization、**S**aturation、**E**rrors
- **Cardinality 是死线**：label 只许小固定集合（路由模板、状态类、provider 名）；user_id、完整 URL、error 文本、request_id 禁当 label，那是日志/trace 的活
- 健康检查 `/healthz` + 存活告警（`up==0`）：没流量时错误率为 0，靠拨测发现挂掉

## Trace

- 入口生成 traceId，`webhook_recv → parse_event → gitea_api → post_comment` 每段一个 span，开始/结束打点（`trace_id, stage, elapsed_ms, status`）
- 错误带段名往上抛，顶层统一 `request_failed`，一眼断段
- 跨异步边界透传（header/消息元数据），否则 trace 断在缝上；默认低采样，错误全留
- `grep trace_id` 即完整时间线：缺结束日志/标 fail 的段即案发段

## 告警（症状不病因）

```
该响（用户痛）：错误率>1%持续5min / p99>2s / 队列老化>10min
看板就行（病因）：CPU 85% / 重启一次 / 磁盘 70%
```

- 每条必须可行动（"忽略会自愈"即删）、有 runbook 链接（啥意思/先查啥/找谁）、有阈值 + 持续窗（SLO 或历史基线倒推，不拍脑袋）
- 两级：page（用户受损现在动）/ ticket（退化本周动）；第三级即噪音训练人无视
- 阈值先看 2-4 周基线再定，跑两周按误报率调；新告警先手动触发一次验通道 + runbook

## 埋点自验（上线前）

- staging 造错 → 拿 requestId 在日志里找到，字段结构化非 `[object Object]`
- 打测试流量 → 指标序列出现，label 符合预期，无高基数
- 跟一个请求走完 trace → 无断 span
- 每条新告警降阈触发一次 → 通道 + runbook 生效

## Quick Reference

| 场景 | 动作 |
|------|------|
| 写生产功能 | 先写 2-4 个值班问题，再选信号 |
| 线上哑 | 结构化 JSON + run_id 全带 + 级别正确 |
| 偶发失败用户先报 | RED + 症状告警 + up==0 存活 |
| 四段断不清 | traceId 全链透传，失败带段名 |
| 加告警 | 症状/可行动/runbook/阈值+窗/试响一次 |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "跑通了再补日志" | 补的时机即第一次事故，最贵时才发现瞎 |
| "日志越多越可观测" | 三个可查事件胜过三百行散文；噪音拖慢定位 |
| "console.log 先顶着" | 不可滤不可关联不可告警；结构化多花 5 分钟一次 |
| "看板有了，出事再看" | 无问题定义的看板除答案外全有；先写值班问题 |
| "全告警后调" | 吵 pager 即训练人无视；调永不来，漏报真来 |
| "user_id 当 label 好查" | 直接打爆 metrics；高基数查属日志/trace |
| "两服务不用 trace" | 跨段耗时日志答不上；ID 透传成本极低 |

## Red Flags — STOP

- 带重试/队列/外部调用的 PR 零新埋点
- 字符串拼接日志无结构化字段
- 无关联 ID，每行是孤儿
- user_id/完整 URL/error 文本当 label
- 延迟只看平均无分位
- 日报式告警（天天响无人动）
- 病因 pager（CPU/内存）响，用户错误率无人盯
- secrets/完整 body 进日志

**以上任一出现 → 停手，补埋点后再合。**

## Verification

- [ ] 值班问题已写下，每信号对号入座
- [ ] 日志全结构化，稳定事件名，每行带关联 ID
- [ ] 无 secrets/token/未脱敏 PII（抽查实际输出）
- [ ] RED 覆盖新 endpoint + 外部依赖，label 有界
- [ ] 延迟是直方图，p95/p99 可查
- [ ] 单请求 trace 端到端无断 span
- [ ] 新告警症状向、有 runbook、试响过一次
