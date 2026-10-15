# .NET 框架级实践（framework-practices）

> 原则与取舍见 `design-principles.md`；组装点与项目结构见 `app-composition.md`。
> 内容以 Microsoft 官方文档为准，凭记忆臆造 API 前先查证。

## 1. DI 生命周期

| 生命周期 | 注册 | 实例 | 典型用途 |
|----------|------|------|----------|
| Transient | `AddTransient` | 每次解析都新建 | 无状态、轻量、短命 |
| Scoped | `AddScoped` | 每个 scope 一个（Web 每请求） | `DbContext`、工作单元/请求级状态 |
| Singleton | `AddSingleton` | 全应用一个 | 全局共享的服务、创建昂贵的对象、缓存、配置 |

选择依据**实际生命周期与线程安全要求**，不要为省实例而无脑 Singleton。Singleton 必须线程安全。

### 怎么选（需求驱动，不是偏好）

官方口径（guidelines）：**多数容器把 `Transient` 作为默认作用域**；`Singleton` 的正当理由是「**全局共享**」或「**创建昂贵**」——官方提醒**不要无理由地给无状态服务加 `Singleton`**，但**全局共享的无状态服务**用 `Singleton` 是常见做法（官方 service-lifetimes 亦言「Singleton 常用于无状态服务」）。所以**不要问「默认用哪个」，按需求选**：

1. **会不会同时存在多份？** 会 → 就不能是 `Singleton`。
2. **谁需要共享同一份？** 共享同一份 → `Scoped`/`Singleton`；各持独立一份 → `Transient`。
3. **实现 `IDisposable` 时，谁负责释放？** 必须能指出释放边界 → 见下节。

> `Scoped` 的「一个 scope」是什么，由**应用决定边界**：Web 是每请求；桌面就是每个窗口 / 每个对话框 / 每次操作——**须自己 `CreateScope()`**（桌面运行时**不会**替你自动开，不同于 ASP.NET 每请求自动开）。

### 可释放对象（`IDisposable`）的归宿

官方硬规则：**不要用 `Transient` 注册 `IDisposable`**；**不要从根容器解析 `Transient`/`Scoped` 的 `IDisposable`**。可释放对象必须有**会被释放的边界**：

| 归宿 | 谁释放 | 何时用（官方按**场景**给方案，无优先级排序） |
|------|--------|--------|
| 工厂（`new` / `ActivatorUtilities.CreateInstance`） | **调用方**（`using`） | 官方「瞬态、有限生命周期」场景：需要新实例、且用后即释放 |
| `Scoped` + 每单元 `CreateScope()` | scope（自动） | 官方「共享实例、有限生命周期」场景：同一工作单元内共享，且随 scope 结束释放 |
| `Singleton` | 容器（关机时一次） | 全局共享、创建昂贵、且线程安全 |
| ~~`Transient`（从根/长命 scope 解析）~~ | ❌ 无边界 → 泄漏 | **禁止**（见「🔴 可释放瞬态被容器强引用」） |

> ⚠️ 官方另有规则：**接收方不要手动 `Dispose` 由容器解析出来的依赖**（官方原话「The receiver of the IDisposable dependency shouldn't call Dispose on that dependency」）。**可释放对象若由容器拥有，就交给容器释放**；只有**工厂模式**（容器不拥有）才由调用方 `using`。两者混用 = 二次释放。

> `IServiceScopeFactory` **始终注册为 Singleton**（官方：always registered as a singleton），任何用了 DI 的应用都能直接注入；scope 的**创建时机与边界由你决定**。

### captive dependency（头号坑）

长生命周期服务**不能**直接注入更短生命周期的依赖：

```csharp
// ❌ Singleton 捕获 Scoped/Transient：短命依赖被提升为单例
services.AddSingleton<ReportService>();   // 依赖 IRepository(Scoped)
services.AddScoped<IRepository, EfRepository>();
```

- 真正要避免的是 **Singleton 捕获 Scoped**（如 `IOptionsSnapshot`、`DbContext`）——开发环境 `ValidateScopes`/`ValidateOnBuild` 会直接报错。
- Singleton 依赖 Transient 是**允许**的，但该 Transient 会被提升为单例生命周期、**必须线程安全**。
- **但若该 Transient 实现 `IDisposable`/`IAsyncDisposable`，规则完全不同**——见下节，`ValidateScopes` **拦不住**这种情况。
- `IOptions`/`IOptionsMonitor`/`ILogger` 都是 Singleton，可安全注入任何生命周期。
- **typed client（`AddHttpClient<T>`）是 Transient**，不要被 Singleton 捕获（见第 4 节）。

### 开启动态校验（开发环境）

- ASP.NET Core / Generic Host 在开发环境默认开 `ValidateScopes`、`ValidateOnBuild`，会启动即抛“Cannot consume scoped service from singleton”。
- 手动 `BuildServiceProvider` 时显式传 `new ServiceProviderOptions { ValidateScopes = true, ValidateOnBuild = true }`。
- 排查“无法解析 X while attempting to activate Y”：注册顺序、生命周期、构造函数歧义（多个可解析构造函数会抛异常）。

### 🔴 可释放瞬态被容器强引用（隐形泄漏 · 红区）

> **这是红区，不是建议。** 命中即停手改正，不要用下列理由放行——每一条都已在本机实测推翻：

| 你的辩解 | 实测事实 |
|---|---|
| 「我在循环里 `using` 了，没漏」 | 实例仍被根容器**强引用**，20 万次解析后堆增长 **206 MB**；`using` 只释放资源，**不摘引用** |
| 「我把 `Dispose` 写好了」 | 容器在 scope 释放时会**再 `Dispose` 一次**——你的用法变成**二次释放** |
| 「我改成工厂注册绕开追踪」 | `AddTransient(sp => new X())` **照样被追踪**（实测堆增长 103 MB） |
| 「开发环境开了 `ValidateScopes`」 | 只校验 `Scoped`；从根容器解析 Transient **完全静默**（实测无异常） |
| 「跑了几个月都正常」 | 泄漏是**线性累积**：1 次/秒 ≈ 每天 8.6 万个永不回收的对象，崩溃只是时间问题 |

**规则：容器会强引用它创建的每一个 `IDisposable`/`IAsyncDisposable` 实例，直到「拥有它的那个 scope」被释放。** 根容器（root provider）本身就是一个 scope，活到进程退出——所以**从根容器解析可释放瞬态 = 内存只增不减**。

三点反直觉，务必记住：

- **每个实例被永久钉在堆上**：托管内存随解析次数无界增长（句柄另算）。
- **手动 `Dispose()` 救不了**：`Dispose` 只释放该实例自己的资源，**不会**把它从容器的追踪列表里摘掉；它反而会**二次释放**（容器在 scope 释放时再 `Dispose` 一次）。
- **`ValidateScopes` / `ValidateOnBuild` 拦不住**：它们只校验 **Scoped** 的捕获式依赖，对「从根容器解析 Transient」完全静默。官方 guidelines 也明说：**不要用 Transient 生命周期注册 `IDisposable`**。

典型触发点（都长得很正常）：

```csharp
// ❌ Singleton 里注入 IServiceProvider（= 根容器），每次循环都解析一个可释放瞬态
public sealed class PollingService(IServiceProvider provider) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            using var session = provider.GetRequiredService<PlcSession>(); // PlcSession : IDisposable
            await session.PollAsync(ct);   // 每秒泄漏一个，ValidateScopes 全程无感
            await Task.Delay(1000, ct);
        }
    }
}
```

改法（**官方正面回答是：不要用 `Transient` 注册 `IDisposable`**，然后二选一——`Scoped` 走 scope，或工厂模式由消费者释放）：

1. **开一个 scope，把工作单元关进去**：

   ```csharp
   public sealed class PollingService(IServiceScopeFactory scopes) : BackgroundService
   {
       protected override async Task ExecuteAsync(CancellationToken ct)
       {
           using var timer = new PeriodicTimer(TimeSpan.FromSeconds(1));
           while (await timer.WaitForNextTickAsync(ct))
           {
               await using var scope = scopes.CreateAsyncScope();   // 每轮一个 scope
               var session = scope.ServiceProvider.GetRequiredService<PlcSession>();
               await session.PollAsync(ct);
               // 不要再自己 using session：交给 scope，避免二次释放
           }
       }
   }
   ```

   - `IServiceScopeFactory` 由容器自动提供，**无需注册**；Singleton 里**只注入它**，不要注入 `IServiceProvider` 当定位器。
   - 这是官方教程「Use scoped services within a BackgroundService」与官方 overview 的范本写法。

> ⚠️ `CreateScope()` 只在**每轮/每批**创建时才有效。把 scope 建在长循环**外面**，等于换成另一个长命 scope，照样累积。

2. **提升为 `Scoped`**：若「一个工作单元一个实例」正是语义，直接注册 `AddScoped`——既表达意图，又让 `ValidateScopes`/`ValidateOnBuild` 重新生效（误注入 Singleton 会**启动即报错**）。**能用 `Scoped` 就不要用 `Transient`**，这是最省心的护栏。

3. **工厂模式**（官方对「瞬态、有限生命周期」场景的正式方案）：**根本不注册**这个类型，改为注册一个**工厂**（单例），由它提供实例、由消费者负责释放——容器不认识这些实例，自然不追踪。**这是官方认可的解法，不是绕路**：

   ```csharp
   public sealed class PlcSessionFactory(IServiceProvider sp)   // 或注册为 static 工厂
   {
       public PlcSession Create() => new PlcSession();          // 无依赖时直接 new
       // 有依赖时：ActivatorUtilities.CreateInstance<PlcSession>(sp) —— 官方推荐的工厂实现手段
   }

   services.AddSingleton<PlcSessionFactory>();
   // 消费方：using var session = factory.Create();
   ```

   > 注意：`AddTransient(sp => new PlcSession())` **不是**工厂模式——它仍注册为 Transient，工厂创建的实例**照样被追踪**。

4. 也可用 `ActivatorUtilities.CreateInstance<T>(sp)` 直接构造（容器不追踪），无需额外工厂类；代价是它**绕过 DI 校验**，依赖关系不如显式工厂清晰。

### 权威来源（改写自官方原文，非二手结论）

- 官方 guidelines「IDisposable guidance for transient and shared instances」：
  - **Don't register `IDisposable` instances with a transient lifetime. Use the factory pattern instead.**
  - **Don't resolve `IDisposable` instances with a transient or scoped lifetime in the root scope.**
  - 官方对照两种改法：「瞬态、有限生命周期」→ 工厂模式（工厂可注入 `IServiceProvider`，用 `ActivatorUtilities.CreateInstance` 构造并自行释放）；「共享实例、有限生命周期」→ `Scoped` + `IServiceScopeFactory.CreateScope()`。
  - 官方另有明确规则：**接收方不应手动 `Dispose` 由容器解析出来的依赖**（「The receiver of the IDisposable dependency shouldn't call Dispose on that dependency」）——即：**给了容器托管就不要再手动释放**，两者混用会造成二次释放。
- 教程「Use scoped services within a BackgroundService」+ overview「Scope scenarios」：`BackgroundService` / `IHostedService` 用 `IServiceScopeFactory` + `CreateAsyncScope()`（官方两处均给出同一范本）。
- 教程「Use the .NET Generic Host in a WPF app」：桌面推荐 `Host.CreateApplicationBuilder` + 去掉 `StartupUri` + `Startup`/`Exit` 挂接 + `_host.Services.GetRequiredService<MainWindow>()`。
- API 文档 dotnet/runtime PR #124248（2026-02 合并）：`IServiceScopeFactory.CreateScope` 的 XML 注释补写「scope 释放时 **scoped 与 transient** 都会被释放」——即此歧义连官方 API 文档此前都未写清。

**自检：** 只要有 `while` / `Timer` / `foreach` 循环里出现 `GetRequiredService<T>`，且 `T` 可能实现 `IDisposable`，就逐条问：这个实例归哪个 scope？scope 多久释放一次？

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

**Options 属于应用级装配层**：进程级、随应用装配、全应用共享，**与用户侧设置无关，与 MVVM 无关**——用户可编辑的设置由可通知的配置模型承载，不要塞进 Options。

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

- I/O 绑定一律 `async/await`；库代码用 `ConfigureAwait(false)`（需要回到 UI 线程的代码除外；ASP.NET Core 无同步上下文，`ConfigureAwait(false)` 非必需）。
- 禁止 `.Result` / `.Wait()`（死锁 + `AggregateException`）。
- 禁止 `async void`；仅**框架回调 / override**（WPF `OnStartup`/`OnExit`、WinForms 事件等签名不可改的框架回调，本质同事件处理器）例外。
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
  - 其中「IDisposable guidance for transient and shared instances」与「Disposable transient services captured by container」即上文红线依据
- Service lifetimes — https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/service-lifetimes
- Options pattern — https://learn.microsoft.com/dotnet/core/extensions/options
- IHttpClientFactory — https://learn.microsoft.com/dotnet/core/extensions/httpclient-factory
- HttpClient guidelines — https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines
