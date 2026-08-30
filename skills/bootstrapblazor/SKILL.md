---
name: bootstrapblazor
description: Use when working with BootstrapBlazor (also called BB, bb, or bootstrapblazor) components and needing their parameters, events, or public methods — e.g. before writing or modifying Razor/C# code that depends on a BB component API (Table, Dialog, Upload, etc.), or when unsure whether a BB API exists or what its exact name/signature is. Get official docs via the bb-llms CLI; never invent APIs from memory.
---

# BootstrapBlazor 组件文档

## Overview

BootstrapBlazor（BB / bb / bootstrapblazor）组件库的参数 / 事件 / 公开方法，**必须**通过 `bb-llms` CLI 从官方文档获取，**禁止凭记忆臆造 API**。

## 前置依赖（bb-llms 缺失时）

本技能依赖 `bb-llms` CLI（.NET 全局工具，包名 `BootstrapBlazor.LLMsDocs.Cli`）。

1. 先检测：`Get-Command bb-llms`（Linux/macOS：`which bb-llms`）
2. 命令不存在 → **停止查文档，不要自行安装、不要臆造 API**，提示用户手动安装：
   - 需先安装 .NET 10 SDK
   - 安装：`dotnet tool install -g BootstrapBlazor.LLMsDocs.Cli`
   - 官方说明：https://github.com/BootstrapBlazor/BootstrapBlazor.Extensions/tree/master/tools/BootstrapBlazor.LLMsDocs.Cli
   - 装完需重开终端使 PATH 生效
3. 用户确认装好后，继续本技能流程

## When to Use

- 需要某个 BB 组件的参数、事件或公开方法（Table、Dialog、Upload 等）
- 不确定某 API 是否存在、名称或签名是否正确
- 编写或修改依赖 BB 组件 API 的代码之前

## Quick Reference

| 需求 | 命令 |
|------|------|
| 查找组件名 | `bb-llms search <关键词>` |
| 获取组件文档 | `bb-llms get <ComponentName>`（例：`bb-llms get Table`） |
| 列出全部组件 | `bb-llms list` |

## 文档源

- 默认源：`https://www.blazor.zone/llms`，按需联网拉取并本地缓存
- 可用环境变量 `BB_LLMS_BASE_URL` 或 `--base-url` 参数指向自建 / 本地源
- 例：`bb-llms --base-url <url> get Table`

## Example

任务：给 Table 加导出功能，但不记得导出参数名。

1. `bb-llms search export` → 确认相关组件 / 方法名
2. `bb-llms get Table` → 查阅导出相关参数与事件，按文档签名实现

## Common Mistakes

- 凭记忆写 API（猜测事件名 / 参数名）→ 一律先用 `bb-llms get` 查证
- 组件名拼写不确定 → 先 `bb-llms search` 或 `bb-llms list`
- `bb-llms` 命令不存在 → 见「前置依赖」章节，提示用户安装，勿臆造
- CLI 已装但联网/拉取失败（如脱机）→ 用浏览器查 https://www.blazor.zone 官方文档，仍不得臆造
