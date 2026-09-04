---
name: security-and-hardening
description: Use when handling user input, secrets, tokens, or file paths, when building auth or external integrations, when auditing dependencies for vulnerabilities, or when reviewing a change for injection, traversal, or secret leaks.
---

# Security and Hardening（安全加固）

## Overview

把每个外部输入当敌对，每个 secret 当圣物，每次鉴权当必查。安全不是阶段，是压在每行碰用户数据、鉴权、外部系统代码上的约束。先画威胁模型再上手段：没说清信任边界的功能不配谈安全。

参考：`addyosmani/agent-skills` 的 `security-and-hardening`（STRIDE、Three-Tier Boundary、OWASP Top 10）。

## When to Use

- 碰用户输入、文件路径、shell 命令拼接时
- 存 token/secret、做鉴权、调外部 API 时
- 加文件上传、webhook、回调时
- 审计依赖漏洞（`npm audit` / `dotnet list package --vulnerable`）时
- 合并前做安全 review 时

**When NOT to use:**

- 纯文档、注释、格式改动
- 已有威胁模型且本次不碰边界，只是内部重构

## 威胁模型先行（5 分钟，动码前做）

1. **画信任边界**：不可信数据从哪进？CLI 参数、环境变量、HTTP 请求、文件、第三方 API、LLM 输出。每条边界即攻击面。
2. **点资产**：什么值得偷/搞？token、凭据、PII、管理员动作、发版产物。
3. **STRIDE 速扫**（镜头不是仪式）：仿冒/篡改/否认/泄露/DoS/提权，每条问一句"能吗"，答不上即缺手段。
4. **写 abuse case**：每个功能问"我怎么滥用它"，滥用即第一个测试。

说不清边界即 OWASP A04（不安全设计），停手先画边界。

## 三级边界（Always / Ask / Never）

### Always（无例外）

- 外部输入在系统边界校验（CLI 参数、API 路由、文件路径），校验完再用
- 数据库查询参数化，禁字符串拼接 SQL
- 输出编码防注入（shell 用参数数组 + `shell:false`，不用 `exec` 拼字符串）
- 外部通信走 HTTPS；密码 bcrypt/scrypt/argon2 存哈希
- 发版前跑包管理器原生审计（`npm audit` / `dotnet list package --vulnerable`），high+ 必须处置
- 路径用 `resolve→realpath` 规范化，拒空/`\0`/超长/以 `-` 开头，传参用数组 + `--` 分隔

### Ask First（需人批准）

- 新增/改动鉴权流程
- 存新类别敏感数据（PII、支付）
- 新增外部服务集成
- 改 CORS / 上传 / 限流
- 提权、改权限模型

### Never（禁令）

- secrets 进代码、进 git、进日志（token、key、密码）
- 客户端校验当安全边界
- `eval` / shell 字符串拼接跑用户输入
- 关安全头图方便；向用户暴露堆栈与内部错误细节
- session/token 放客户端可读存储

## Secrets 分层

```
代码 ← 只读环境变量，无值即报错退出，不给默认值
本地 ← .env（gitignore）+ .env.example 占位
CI   ← Gitea/GH Secrets → ${{ secrets.X }} → 环境变量，不 echo 不落盘
生产 ← 部署平台/密钥管理，CI 永远不持生产密钥
泄露 ← 按已泄露处理：吊销重建 + git filter-repo 清历史，光 git rm 不够
```

## 注入与遍历（本仓高频）

- 命令注入：`--target="a;rm -rf /"`、`$(id)`、反引号、`&&|||`——解法：`spawnSync(cmd, args[])` + `shell:false`，输入只当 `cwd`/参数，不进命令字符串
- 参数注入：`--target="--upload-pack=..."` 以 `-` 开头被当 option——解法：拒 `-` 开头 + `--` 分隔
- 路径遍历：`--target="../../etc"` + `join+writeFileSync` 写出仓外——解法：`resolve→realpath` 后断言仍在根内，`existsSync+isDirectory`，非目标目录拒绝
- SQL 注入：参数化 / ORM，禁拼接
- XSS/输出注入：框架自动转义，不绕过；必须渲染 HTML 先 sanitize

## 依赖漏洞处置

```
audit 报 high+ → 先判可达性（走不走那条路径）
  → 可达：先临时缓解（限输入/关特性/pin+最小补丁）降暴露面，同时开分支试升级
  → 不可达：记录 + 跟踪，不无视
  → 压着不升 = 留雷；直接升 = 拿生产当测试；都不接受
```

## Quick Reference

| 场景 | 动作 |
|------|------|
| 用户输入进命令 | 参数数组 + shell:false，不拼字符串 |
| 路径输入 | resolve→realpath→断言在根内→isDirectory |
| token/secret | 环境变量 + Secrets，禁代码/日志/git |
| 发版前 | 原生审计跑一次，high+ 有处置记录 |
| 碰边界 | 先 STRIDE 5 分钟 + abuse case 当首测 |
| 改鉴权/加集成 | Ask First，先批再做 |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "内部工具，不用校验输入" | 内部工具的调用方也是不可信输入；注入不分内外，边界即校验 |
| "先拼字符串，上线前再改参数数组" | 上线前即忘记时；拼字符串是 Never 级，出现即拦 |
| "这个漏洞我们走不到" | 走不到是结论不是感觉；拿出调用链证据，否则按可达处置 |
| "升级会 break，先压着" | 压着=留雷；先缓解降暴露面，再排期升级，两步都得有记录 |
| "日志打 token 方便排查" | 排查方便泄露也方便；脱敏/引 ID，值永不进日志 |
| "误提交了 git rm 就行" | 历史里还在；吊销重建 + filter-repo 清历史 |

## Red Flags — STOP

- shell 字符串拼接用户输入（`exec("..."+input)`）
- 路径未规范化即 `join+write`
- secret 进代码/git/日志
- audit high+ 无处置记录
- 碰信任边界无 STRIDE / 无 abuse case
- 关安全检查图方便（headers、校验、CORS）
- 向用户吐堆栈与内部细节

**以上任一出现 → 停手，修代码不修 bar。**

## Verification

- [ ] 威胁模型已画（边界/资产/STRIDE/abuse case）
- [ ] 输入在边界校验，命令用参数数组，路径规范化 + 根内断言
- [ ] secrets 全走环境变量/Secrets，无代码/日志/git 残留
- [ ] 发版审计已跑，high+ 有可达性结论 + 处置记录
- [ ] Ask First 项有人批准记录
