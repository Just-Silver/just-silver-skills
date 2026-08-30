---
name: bootstrapblazor
description: Use when working with BootstrapBlazor (also called BB, bb, or bootstrapblazor) components and needing their parameters, events, or public methods — e.g. before writing or modifying Razor/C# code that depends on a BB component API (Table, Dialog, Upload, etc.), or when unsure whether a BB API exists or what its exact name/signature is. Get official docs via the bb-llms CLI; never invent APIs from memory.
---

# BootstrapBlazor 组件文档

## Overview

BootstrapBlazor（BB / bb / bootstrapblazor）组件库的参数 / 事件 / 公开方法，**必须**通过 `bb-llms` CLI 从官方文档获取，**禁止凭记忆臆造 API**。

## 前置依赖检测（硬性第一步，不可跳过）

本技能依赖 `bb-llms` CLI（.NET 全局工具，包名 `BootstrapBlazor.LLMsDocs.Cli`）。

在回答任何 BB API 问题之前，**必须**先验证 `bb-llms` 可用：

1. 运行 `bb-llms --help`（或 `-h`）：
   - 正常输出 Usage / Commands → CLI 存在且可运行；核对 Commands 列表确认 search / get / list 等子命令名，以实际输出为准
   - 命令报错（找不到命令 / 非零退出码 / 无输出）→ 视为不可用，**立即停止查文档**
2. 不可用时按下方「安装引导」提示用户手动安装（需先安装 .NET 10 SDK），装完需重开终端使 PATH 生效
3. 用户确认装好后，重新执行第 1 步，通过后再继续查文档

### 安装引导

- 安装：`dotnet tool install -g BootstrapBlazor.LLMsDocs.Cli`
- 官方说明：https://github.com/BootstrapBlazor/BootstrapBlazor.Extensions/tree/master/tools/BootstrapBlazor.LLMsDocs.Cli
- **不得自行安装、不得凭记忆臆造 API**；安装由用户执行

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
- `bb-llms --help` 报错/无输出 → 视为不可用 → 见「前置依赖检测」章节，提示用户安装，勿臆造
- CLI 已装但联网/拉取失败（如脱机）→ 用浏览器查 https://www.blazor.zone 官方文档，仍不得臆造
