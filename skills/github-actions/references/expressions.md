# 表达式与函数（GitHub Actions）

> 官方源：https://docs.github.com/en/actions/reference/workflows-and-actions/expressions
> 本文件为提炼要点，函数完整签名以官方页为准。

## 字面量与语法

- 用 `${{ }}` 包裹表达式；字符串须用**单引号**（双引号会报错），单引号转义用 `''`
- 字面量：`true` / `false` / `null` / 数字（JSON 支持格式）/ 字符串
- `if:` 条件中假值：`false`、`0`、`-0`、`""`、`''`、`null` → false；其余为 true
- 字符串比较**忽略大小写**；类型不匹配时强制转数字比较（`"abc"` → `NaN`，`NaN` 任何比较都是 false）

## 运算符

| 运算符 | 含义 |
|--------|------|
| `( )` | 分组 |
| `[ ]` / `.` | 索引 / 属性 |
| `!` | 非 |
| `<` `<=` `>` `>=` | 比较 |
| `==` `!=` | 相等（松散比较，字符串忽略大小写） |
| `&&` \|\| `\|\|` | 与 / 或 |

## 函数速查

| 函数 | 作用 | 示例 |
|------|------|------|
| `contains(search, item)` | 包含（数组元素 / 字符串子串，不区分大小写） | `contains(github.event.issue.labels.*.name, 'bug')` |
| `startsWith(s, v)` | 以...开头（忽略大小写） | `startsWith(github.ref, 'refs/heads/releases/')` |
| `endsWith(s, v)` | 以...结尾 | `endsWith('Hello world', 'ld')` |
| `format(s, v0, v1, ...)` | 格式化替换 `{0}` `{1}` | `format('Hello {0}', 'Mona')` |
| `join(arr, sep)` | 数组合并字符串 | `join(github.event.issue.labels.*.name, ', ')` |
| `toJSON(value)` | 转 JSON 字符串（调试输出上下文） | `toJSON(github)` |
| `fromJSON(value)` | JSON 字符串转对象/值（布尔/数字转换） | `fromJSON('["push","pull_request"]')` |
| `hashFiles(path)` | 文件集 SHA-256 哈希（缓存 key） | `hashFiles('**/package-lock.json')` |
| `case(pred1, val1, ..., default)` | 按顺序取第一个为 true 对应的值 | `case(github.ref == 'refs/heads/main', 'prod', 'dev')` |

## 状态检查函数（if 条件）

| 函数 | 含义 |
|------|------|
| `success()` | 前面所有步骤成功（`if` 默认值） |
| `failure()` | 前面某步骤失败（或祖先 job 失败） |
| `cancelled()` | 被取消 |
| `always()` | 总是执行（**慎用**，推荐 `!cancelled()`） |

- `if` 条件不含任何状态函数时，默认是 `success()`
- 推荐替代 `always()`：`if: ${{ !cancelled() }}`（避免在严重失败时继续拉源码导致挂起）

## 对象过滤器（Object filters）

- `*` 通配选择集合属性：`github.event.issue.labels.*.name` → 所有 label 的 name 数组
- 对象属性无顺序保证

## 调试技巧

- 输出上下文：`env: { GITHUB_CONTEXT: ${{ toJSON(github) }}, JOB_CONTEXT: ${{ toJSON(job) }}, STEPS: ${{ toJSON(steps) }} }` 然后 `run: echo "$GITHUB_CONTEXT"` 等
- **警告**：`github` 上下文含 `github.token` 等敏感信息，打印时 GitHub 会打码，但仍应谨慎导出

## 常见陷阱

- `steps.<id>.outputs.<name>` 求值为字符串，需要数字比较时用 `fromJSON()` 转
- `contains` 大小写不敏感；字符串比较忽略大小写（`'FOO' == 'foo'` 为 true）
- `if` 条件中 `${{ }}` 可省略（官方新写法 `if: github.ref == 'refs/heads/main'`），`${{ }}` 写法兼容性更广，二选一即可；勿两种混用出错
- 含字符串或函数的 `if` 值若以非表达式写会按 YAML 字符串处理，注意引号
