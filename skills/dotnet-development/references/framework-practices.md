# .NET 框架级实践（framework-practices）

> 原则与取舍见 `design-principles.md`；组装点与项目结构见 `app-composition.md`。
> 内容以 Microsoft 官方文档为准，凭记忆臆造 API 前先查证。

## 1. DI 生命周期

| 生命周期 | 注册 | 实例 | 典型用途 |
|----------|------|------|----------|
| Transient | `AddTransient` | 每次解析都新建 | 无状态、轻量、短命 |
| Scoped | `AddScoped` | 每个 scope 一个（Web 每请求） | `DbContext`、请求级状态 |
| Singleton | `AddSingleton` | 全应用一个 | 无状态共享服务、缓存、配置 |

选择依据**实际生命周期与线程安全要求**，不要为省实例而无脑 Singleton。Singleton 必须线程安全。

### captive dependency（头号坑）

长生命周期服务**不能**直接注入更短生命周期的依赖：

```csharp
// ❌ Singleton 捕获 Scoped/Transient：短命依赖被提升为单例
services.AddSingleton<ReportService>();   // 依赖 IRepository(Scoped)
services.AddScoped<IRepository, EfRepository>();
```

- Singleton 只能依赖 Singleton（`IOptions`、`IOptionsMonitor`、`ILogger` 都是 Singleton，安全）。
- Scoped/Transient 服务可以依赖 Scoped/Transient/Singleton。
- `IOptionsSnapshot` 是 Scoped，**不能**注入 Singleton。
- **typed client（`AddHttpClient<T>`）是 Transient**，不要被 Singleton 捕获（见第 4 节）。

### 开启动态校验（开发环境）

- ASP.NET Core / Generic Host 在开发环境默认开 `ValidateScopes`、`ValidateOnBuild`，会启动即抛“Cannot consume scoped service from singleton”。
- 手动 `BuildServiceProvider` 时显式传 `new ServiceProviderOptions { ValidateScopes = true, ValidateOnBuild = true }`。
- 排查“无法解析 X while attempting to activate Y”：注册顺序、生命周期、构造函数歧义（多个可解析构造函数会抛异常）。

## 2. Options（强类型配置）

避免散读 `Environment.GetEnvironmentVariable` / `IConfiguration["X:Y"]`（魔法字符串、无类型、无校验）。

```csharp
public sealed class OrderApiOptions
{
    public const string SectionName = "OrderApi";
    public string BaseUrl { get; set; } = string.Empty;   // Options 类需 public 读写属性 + 无参构造
    public int TimeoutSeconds { get; set; } = 15;
}
```

```csharp
builder.Services.AddOptions<OrderApiOptions>()
    .Bind(builder.Configuration.GetSection(OrderApiOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();   // 配置错误在启动即失败，而非首次使用
```

选择哪个接口：

| 接口 | 生命周期 | 是否热更新 | 用于 |
|------|----------|-----------|------|
| `IOptions<T>` | Singleton | 否 | 启动后不变的配置（连接串、密钥） |
| `IOptionsSnapshot<T>` | Scoped | 每请求 | 请求级/可重载配置、命名选项 |
| `IOptionsMonitor<T>` | Singleton | 实时 + `OnChange` | 单例中读实时配置、特性开关 |

`IOptions<T>.Value` 是启动时冻结的快照；需要热更新时用 Snapshot/Monitor。

## 3. 日志（结构化 + `ILogger<T>`）

```csharp
public sealed class OrderService
{
    private readonly ILogger<OrderService> _logger;
    public OrderService(ILogger<OrderService> logger) => _logger = logger;

    public void Place(string orderId, decimal amount) =>
        _logger.LogInformation("订单已创建 {OrderId}，金额 {Amount}", orderId, amount);
}
```

- 注入 `ILogger<T>`，**不要** `Console.WriteLine`，也不要在业务代码里依赖 Serilog/NLog 等具体实现（在组装点接入 provider）。
- 用**结构化占位符**（`{OrderId}`），不要把值拼进消息字符串——否则无法按字段检索。
- 级别：`Trace/Debug` 诊断、`Information` 业务里程碑、`Warning` 可恢复异常、`Error` 需关注的失败、`Critical` 致命。
- 记录上下文与异常对象：`_logger.LogError(ex, "... {Id}", id)`。

## 4. HttpClient / `IHttpClientFactory`

`new HttpClient()` 长期持有会导致 **DNS 不更新**；频繁 `new` 会导致 **端口耗尽（TIME_WAIT）**。

两种推荐做法（.NET 5+）：

1. **`IHttpClientFactory` typed client（首选）**：
   ```csharp
   services.AddHttpClient<IWeatherGateway, WeatherGateway>((sp, http) =>
   {
       var opt = sp.GetRequiredService<IOptions<WeatherOptions>>().Value;
       http.BaseAddress = new Uri(opt.BaseUrl);
       http.Timeout = TimeSpan.FromSeconds(opt.TimeoutSeconds);
   });
   ```
   - typed client 是 **Transient**，工厂池化底层 `HttpMessageHandler`（默认 2 分钟）以复用连接并响应 DNS 变化。
   - **不要**把 typed client 捕获进 Singleton（会阻止 handler 轮换）。Singleton 里应注入 `IHttpClientFactory` 并 `CreateClient()`。
2. **长生命周期 client + `PooledConnectionLifetime`**：`static`/Singleton client，设 `SocketsHttpHandler.PooledConnectionLifetime`（如 2 分钟）。

- 需要重试/熔断/超时：`.AddStandardResilienceHandler()`（`Microsoft.Extensions.Http.Resilience`），**只加一个** resilience handler，不要叠加。
- 需要 cookie 的场景慎用工厂（handler 池化会共享 `CookieContainer`）。

## 5. 异常处理

- 异常表达**真正异常**，不作普通控制流。
- 只捕获**能处理**的异常；否则 `throw;` 继续向上（用 `throw;` 而非 `throw ex;`，保留堆栈）。
- 不要 `catch (Exception) { }` 静默吞掉；不要无意义地捕获后重新包装。
- 补上下文时保留内部异常：`throw new WeatherGatewayException("调用失败", ex);`
- 区分“调用方取消”与“超时”：
  ```csharp
  catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; } // 主动取消
  catch (TaskCanceledException ex) { /* 超时 */ }
  ```
- 用异常过滤器 `when` 而非在 `catch` 里 `if` 判断。
- 边界层（Controller/中间件/UI）统一映射为响应或用户提示；内部层只负责抛。
- **不要每层都 `catch` + 记日志 + `throw`**：同一异常被反复记录，日志噪音且丢失“谁真正处理了”的信号。异常只在**能处理或需要补充上下文**的层捕获并记录一次。

## 6. async / await

- I/O 绑定一律 `async/await`；库代码用 `ConfigureAwait(false)`（UI/ASP.NET 上下文敏感的代码除外）。
- 禁止 `.Result` / `.Wait()`（死锁 + `AggregateException`）。
- 禁止 `async void`，事件处理器除外。
- 公开异步方法接受 `CancellationToken` 并向下传递：
  ```csharp
  public async Task<IReadOnlyList<Order>> GetAsync(CancellationToken ct = default)
  ```
- 不要 `Task.Run` 包装同步 CPU 工作来“假装异步”。

## 7. 数据访问边界

- 业务/应用逻辑不直接依赖 `SqlConnection`、具体 SQL、ORM 细节；通过明确边界接入。
- EF Core `DbContext` 默认 **Scoped**；注册为 Singleton 的服务不得直接注入它（captive dependency）。后台服务里用 `IServiceScopeFactory` 建 scope 再解析。
- 仓储不是必需品：ORM 已提供工作单元/查询抽象时，一对一转发的 `IRepository` 只增加跳转。**只有需要隔离实现、替换、或测试接缝时才引入。**

## 8. 可测试性

- 时间：注入 `TimeProvider`（现代 .NET），测试用 `FakeTimeProvider`，不要到处 `DateTime.Now`。
- 外部 IO：抽象为接口，通过 DI 隔离。
- 不要为测试给生产代码加特殊入口；设计本身应可测试。

## 9. 现代 .NET 优先（按需）

`record` / `record struct`、`required`、nullable reference types、集合表达式、primary constructor、`System.Text.Json` 源生成、`TimeProvider`。以清晰度和实际需求为准，不为新而新。

## 参考

- Dependency injection guidelines — https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/guidelines
- Service lifetimes — https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/service-lifetimes
- Options pattern — https://learn.microsoft.com/dotnet/core/extensions/options
- IHttpClientFactory — https://learn.microsoft.com/dotnet/core/extensions/httpclient-factory
- HttpClient guidelines — https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines
