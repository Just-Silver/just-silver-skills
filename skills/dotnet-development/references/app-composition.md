# 应用组装与项目结构（app-composition）

> 适用于 WPF / WinForms / Avalonia / MAUI / 控制台 / Worker / 类库等**非 Web 或非默认带 DI 的**项目。
> 原则见 `design-principles.md`，框架实践见 `framework-practices.md`。

## 核心：Composition Root

任何 .NET 应用都应有**一个组装点（Composition Root）**：在启动处注册服务、构建容器、解析入口对象。业务代码只依赖抽象，不认识容器。

- Web（ASP.NET Core）天然有 `Program.cs`。
- **桌面与控制台默认没有**——必须主动引入 `Microsoft.Extensions.Hosting`（或至少 `Microsoft.Extensions.DependencyInjection`）。
- 组装点**只**在启动/退出时碰容器；业务代码里出现 `GetService` / `Ioc.Default` 即 Service Locator 反模式。

最小依赖：

```
Microsoft.Extensions.Hosting   # Generic Host：DI + 配置 + 日志 + 生命周期
```

桌面 UI 通常再配 `CommunityToolkit.Mvvm`（MVVM 源生成器）与 `Microsoft.Extensions.Http`（`IHttpClientFactory`）。

## WPF

### App.xaml：去掉 `StartupUri`

```xml
<Application x:Class="MyApp.App"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <Application.Resources />
</Application>
```

主窗口由容器解析后手动 `Show()`，因此不要设置 `StartupUri`。

### App.xaml.cs：Generic Host 装配

```csharp
public partial class App : Application
{
    private readonly IHost _host;

    public App()
    {
        _host = Host.CreateApplicationBuilder()   // 自动加载 appsettings.json + 日志 + 配置
            .Build();
    }

    protected override async void OnStartup(StartupEventArgs e)
    {
        await _host.StartAsync();

        var mainWindow = _host.Services.GetRequiredService<MainWindow>();
        mainWindow.Show();

        base.OnStartup(e);
    }

    protected override async void OnExit(ExitEventArgs e)
    {
        await _host.StopAsync(TimeSpan.FromSeconds(3));
        _host.Dispose();
        base.OnExit(e);
    }
}
```

注册服务（可在 `App` 构造函数里配置 `builder.Services`）：

```csharp
var builder = Host.CreateApplicationBuilder();
builder.Services.AddOptions<ApiOptions>()
    .Bind(builder.Configuration.GetSection("Api"))
    .ValidateDataAnnotations()
    .ValidateOnStart();
builder.Services.AddHttpClient<IApiClient, ApiClient>((sp, http) => { /* BaseAddress/Timeout */ });
builder.Services.AddSingleton<IMessenger>(WeakReferenceMessenger.Default); // 跨 VM 通信
builder.Services.AddSingleton<MainViewModel>();   // 主 VM 单例
builder.Services.AddTransient<DetailViewModel>(); // 每次打开新实例
builder.Services.AddSingleton<MainWindow>();
_host = builder.Build();
```

> 两者默认行为**等价**；新项目推荐 `Host.CreateApplicationBuilder`（`CreateDefaultBuilder` 是传统回调式，用于兼容旧代码）。

### 注入窗口与 ViewModel

```csharp
public partial class MainWindow : Window
{
    public MainWindow(MainViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;   // 有参构造 → 需在隐藏代码里设 DataContext
    }
}
```

### 生命周期选择（桌面易错点）

| 对象 | 建议 | 说明 |
|------|------|------|
| 主窗口 / Shell VM | `Singleton` | 全应用一个 |
| 次级窗口 / 每文档 VM | `Transient` | 每次打开新实例；用 Singleton 会导致关闭后再打开报“无法设置可见性/Show” |
| 数据服务、设置、HTTP 客户端封装 | `Singleton`（除 typed client 外） | 无状态共享 |
| `AddHttpClient<T>` 注册的 typed client | 工厂管理（Transient） | **不要被 Singleton 捕获**（见下） |

**typed client 不要注入 Singleton**：`AddHttpClient<T>` 注册的是 Transient，被 Singleton VM 捕获会阻止 handler 轮换/DNS 更新。需要时改为在 Singleton 中注入 `IHttpClientFactory` 并按需 `CreateClient()`，或把 VM 改为 Transient。

## WinForms

同样用 Generic Host：`Program.Main` 里 `[STAThread]` + `ApplicationConfiguration.Initialize()` 前构建 host，`host.Services.GetRequiredService<MainForm>()` 后 `Application.Run(form)`。`Form` 通过构造函数注入依赖，业务逻辑放 Presenter/Service 而非 Form 事件里。

## Avalonia / MAUI / Uno

同一套：`App` 里建 `IServiceProvider`（Generic Host 或 `ServiceCollection`），在 `OnFrameworkInitializationCompleted` / `MauiProgram.CreateMauiApp` 中注册并解析根 VM/View。禁止用 `Ioc.Default` 作为常规依赖获取方式（仅设计时数据等逃生场景）。

## 控制台

```csharp
var builder = Host.CreateApplicationBuilder(args);
builder.Services.AddOptions<BatchOptions>().Bind(builder.Configuration.GetSection("Batch"));
builder.Services.AddSingleton<IBatchRunner, BatchRunner>();
using var host = builder.Build();

await host.StartAsync();
var runner = host.Services.GetRequiredService<IBatchRunner>();
await runner.RunAsync(host.Services.GetRequiredService<IHostApplicationLifetime>().ApplicationStopping);
await host.StopAsync();
```

简单场景可只用 `ServiceCollection`：

```csharp
var services = new ServiceCollection();
services.AddSingleton<IThing, Thing>();
using var provider = services.BuildServiceProvider(
    new ServiceProviderOptions { ValidateScopes = true, ValidateOnBuild = true });
```

## Worker / 后台服务

`BackgroundService` 是 Singleton，**不能**构造注入 Scoped 依赖（如 `DbContext`）。用 `IServiceScopeFactory` 建 scope：

```csharp
public sealed class SyncWorker(IServiceScopeFactory scopes, ILogger<SyncWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            using (var scope = scopes.CreateScope())
            {
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                // ... 处理
            }
            await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
        }
    }
}
```

注册：`builder.Services.AddHostedService<SyncWorker>();`。长期运行的外部调用（HTTP）失败要记录并重试，不能拖垮主流程。

## MVVM 要点（CommunityToolkit.Mvvm 8.4+，强制）

- ViewModel 通过**构造函数**接收服务、子 VM 与 `IMessenger`；不要 `new` 服务，不要用 `Ioc.Default.GetService` 隐藏依赖。
- 属性一律用 `[ObservableProperty]` 的 **partial property 新写法**；禁止手写 `INotifyPropertyChanged`，禁止旧字段写法：

  ```csharp
  public sealed partial class MainViewModel : ObservableObject
  {
      [ObservableProperty]
      [NotifyCanExecuteChangedFor(nameof(RefreshCommand))]
      public partial bool IsBusy { get; set; }
  }
  ```

- 命令用 `[RelayCommand]`（异步方法可带 `CancellationToken`；默认 `AllowConcurrentExecutions = false`，执行期间自动禁用按钮防重复点击），避免 `async void`。
- 需要输入校验的 VM 继承 `ObservableValidator`，用 `[NotifyDataErrorInfo]` + DataAnnotations（`[Required]`/`[EmailAddress]`/`[Range]`…），保存前 `ValidateAllProperties()` 并检查 `HasErrors`。
- 跨 VM/模块通信用注入的 `IMessenger`（默认 `WeakReferenceMessenger.Default`），在 DI 中注册一次。
- 设计时数据用 `d:DataContext="{d:DesignInstance Type=vm:MainViewModel, IsDesignTimeCreatable=True}"`；必要时给无参构造仅供设计器。
- 错误处理分层：服务层记日志并抛；VM 捕获后转成用户可见提示，不让 UI 崩溃。
- 版本/语言要求与完整用法（属性、命令、验证、Messenger、DI 集成）见 `mvvm-communitytoolkit.md`。

## 常见错误

1. **“不是 Web 就不用 DI”**：直接在 code-behind 里 `new HttpClient()` / `new SqlRepository()`，静态 helper 满天飞。→ 引入 Generic Host。
2. **把容器当 Service Locator**：`App.Services.GetRequiredService<X>()` 散落在业务代码。→ 只在 Composition Root 用，其余构造注入。
3. **所有东西 Singleton**：每文档 VM 用 Singleton → 关闭再打开报错、状态串味。→ 按生命周期选。
4. **Singleton 捕获 typed client / `DbContext`**：captive dependency，静默把短命依赖变单例。→ 开发环境开 `ValidateScopes`/`ValidateOnBuild`。
5. **多个 `BuildServiceProvider()`**：每个都是独立容器，Singleton 不共享。→ 启动只建一次。
6. **窗口/VM 构造函数只写无参、依赖靠属性赋值**：隐藏依赖、无法启动期校验。→ 构造注入。
