# CommunityToolkit.Mvvm（mvvm-communitytoolkit）

> MVVM 一律使用 **CommunityToolkit.Mvvm**，禁止手写 `INotifyPropertyChanged` 样板。
> DI 容器一律使用 **Microsoft.Extensions.DependencyInjection**（经 Generic Host 或 `ServiceCollection`）。
> 内容依据 Microsoft 官方文档整理；API 存疑时以官方文档为准，禁止臆造。

## 1. 前置要求（最低版本）

| 项 | 最低要求 | 说明 |
|----|---------|------|
| 包 | `CommunityToolkit.Mvvm` **8.4+** | 偏属性支持自 8.4 起 |
| 语言 | `<LangVersion>preview</LangVersion>` | 生成代码用到 `field` 关键字：C# 13 稳定版没有，故 **.NET 9 SDK 必须用 `preview`**；**C# 14（.NET 10 SDK）**已稳定含 `field`，可直接写 `14` |
| 注意 | `latest` 随 SDK 浮动 | 只有所用 SDK 的 latest ≥ C# 14（即 .NET 10 SDK）时 `latest` 才可用；.NET 9 SDK 上 `latest` = C# 13，会报 `MVVMTK0041` / `CS9248`——报错就把 `<LangVersion>` 改为 `preview` |

```xml
<PropertyGroup>
  <LangVersion>latest</LangVersion>
</PropertyGroup>
<ItemGroup>
  <PackageReference Include="CommunityToolkit.Mvvm" Version="8.4.1" />
  <PackageReference Include="Microsoft.Extensions.Hosting" Version="8.0.0" />
</ItemGroup>
```

## 2. 三个基类怎么选

| 基类 | 提供 | 用于 |
|------|------|------|
| `ObservableObject` | `INotifyPropertyChanged` / `INotifyPropertyChanging` | 普通 VM |
| `ObservableValidator` | 在 `ObservableObject` 上实现 `INotifyDataErrorInfo` | 需要输入校验的 VM |
| `ObservableRecipient` | 在 `ObservableObject` 上集成 `IMessenger`、`IsActive` | 需要收发消息的 VM |

> `ObservableValidator` 与 `ObservableRecipient` 是 `ObservableObject` 下**并列的两条分支**，`ObservableRecipient` **不含校验**。需要「校验 + 消息」时：在 `ObservableValidator` 上自行实现 `IRecipient<T>` 并注册，或继承 `ObservableRecipient` 自行实现校验。

## 3. `[ObservableProperty]`（强制新写法）

### ✅ 使用 partial property（本规范强制）

```csharp
public partial class UserEditViewModel : ObservableObject
{
    [ObservableProperty]
    public partial string? Name { get; set; }

    [ObservableProperty]
    public partial int Age { get; set; }
}
```

生成器补全实现并暴露 `OnNameChanged` / `OnNameChanging` 等分部方法：

```csharp
partial void OnNameChanged(string? value) { /* 属性变更后 */ }
partial void OnAgeChanging(int oldValue, int newValue) { /* 变更前，可访问新旧值 */ }
```

要点：
- 初始化直接在偏属性声明上写即可：`public partial string Name { get; set; } = string.Empty;`。
- 校验特性、`[NotifyPropertyChangedFor]` 等**直接写在属性上**。

### ❌ 禁止旧字段写法

```csharp
// 旧写法：仅为兼容旧项目，新代码禁止
[ObservableProperty]
private string? _name;
```

> **为什么强制偏属性写法**：字段式 `[ObservableProperty]` 生成的属性对**同一编译内的其它源生成器不可见**——例如 System.Text.Json **源生成（`JsonSerializerContext`）**看不到它，序列化时**静默丢字段（写出 `{}`）而不报错**。此坑**只发生在源生成路径**；反射式 `JsonSerializer.Serialize(obj)` 不受影响（运行时能看到生成后的属性）。
> 因此适用范围**不止 VM**：凡是**同时**使用 `[ObservableProperty]`、又可能被其它源生成器（STJ 序列化、配置绑定等）看到的类型（例如既做变更通知、又参与序列化的持久化模型），都必须用偏属性写法。
> **注意**：普通配置 / DTO / 持久化模型本身**不需要** `[ObservableProperty]`——用普通自动属性即可（对源生成器天然可见）；只有确实需要变更通知时才上 `[ObservableProperty]`，且一旦用了就必须是偏属性写法。

### 依赖属性 / 依赖命令通知

```csharp
[ObservableProperty]
[NotifyPropertyChangedFor(nameof(FullName))]      // Name 变 → 通知 FullName
[NotifyCanExecuteChangedFor(nameof(SaveCommand))] // Name 变 → 重新评估命令可用性
public partial string? Name { get; set; }
```

### 触发校验（配合 `ObservableValidator`）

```csharp
public partial class UserEditViewModel : ObservableValidator
{
    [ObservableProperty]
    [NotifyDataErrorInfo]
    [Required(ErrorMessage = "姓名必填")]
    [MinLength(2)]
    public partial string? Name { get; set; }
}
```

### 通过消息广播属性变化（配合 `ObservableRecipient`）

```csharp
[ObservableProperty]
[NotifyPropertyChangedRecipients]
public partial string? Name { get; set; }
```

## 4. `[RelayCommand]`

```csharp
// 异步命令；方法名去掉 Async 后缀 + Command 得到命令名 SaveCommand
[RelayCommand(CanExecute = nameof(CanSave), AllowConcurrentExecutions = false)]
private async Task SaveAsync(CancellationToken ct)
{
    // 传 CancellationToken 时，命令自动支持 IAsyncRelayCommand.Cancel
}

private bool CanSave() => !IsBusy;
```

| 特性参数 | 作用 |
|----------|------|
| `CanExecute = nameof(...)` | 指定可执行性判定方法/属性；属性变化时用 `[NotifyCanExecuteChangedFor]` 或手动 `NotifyCanExecuteChanged()` 失效 |
| `AllowConcurrentExecutions` | 默认 `false`：命令执行期间自动禁用（防重复点击）；`true` 允许并发排队 |
| `IncludeCancelCommand = true` | 额外生成 `XxxCancelCommand` 用于取消 |
| `FlowExceptionsToTaskScheduler` | 默认 `false`（等待并重抛）；`true` 时异常不再崩溃应用，改为流向 `TaskScheduler` |

命名规则：去掉 `On` 前缀、去掉 `Async` 后缀，再追加 `Command`。

## 5. 验证（`ObservableValidator`）

```csharp
public partial class UserEditViewModel : ObservableValidator
{
    [ObservableProperty]
    [NotifyDataErrorInfo]
    [Required]
    [EmailAddress]
    public partial string? Email { get; set; }

    [RelayCommand(CanExecute = nameof(CanSave))]
    private async Task SaveAsync(CancellationToken ct)
    {
        ValidateAllProperties();
        if (HasErrors) { /* 提示用户 */ return; }
        // ...
    }

    private bool CanSave() => !HasErrors;
}
```

- 特性：`[Required]`、`[EmailAddress]`、`[Range]`、`[MinLength]` 等 DataAnnotations，或自定义 `ValidationAttribute` / `[CustomValidation]`。
- 提供 `ValidateProperty`、`ValidateAllProperties`、`ClearAllErrors`、`GetErrors`、`HasErrors`、`ErrorsChanged`。

## 6. Messenger（`IMessenger`）

用于解耦模块间通信，避免强引用。

```csharp
public sealed class LoggedInUserChangedMessage : ValueChangedMessage<User>
{
    public LoggedInUserChangedMessage(User user) : base(user) { }
}

// 发送
messenger.Send(new LoggedInUserChangedMessage(user));

// 接收（实现 IRecipient<T> 并 RegisterAll，或用 lambda 注册）
public sealed partial class ShellViewModel : ObservableRecipient, IRecipient<LoggedInUserChangedMessage>
{
    public ShellViewModel(IMessenger messenger) : base(messenger) { }

    public void Receive(LoggedInUserChangedMessage message) { /* ... */ }
}
```

- 两种实现：`WeakReferenceMessenger`（默认，弱引用，自动回收）与 `StrongReferenceMessenger`（强引用，性能更好但需手动 `Unregister`）。
- 在 DI 中注册一次并注入：`services.AddSingleton<IMessenger>(WeakReferenceMessenger.Default);`
- 支持通道 token、`RequestMessage<T>` / `AsyncRequestMessage<T>` 等请求-应答模式。
- `ObservableRecipient` 配合 `IsActive` 可在激活时自动 `RegisterAll`、停用时自动注销。

## 7. 与 DI 集成（Microsoft.Extensions.DependencyInjection）

```csharp
// App 组合根 / Program
var builder = Host.CreateApplicationBuilder();
builder.Services.AddSingleton<IMessenger>(WeakReferenceMessenger.Default);
builder.Services.AddSingleton<IUserService, UserService>();
builder.Services.AddSingleton<ShellViewModel>();
builder.Services.AddTransient<UserEditViewModel>();   // 每次打开新实例
builder.Services.AddSingleton<MainWindow>();
```

- VM 通过**构造函数**接收服务、子 VM 与 `IMessenger`；不要在 VM 里 `new` 服务。
- **禁止 `CommunityToolkit.Mvvm.DependencyInjection.Ioc.Default`** 作为常规取依赖方式（等价于 Service Locator）；仅设计时数据等无法构造注入的逃生场景可用。
- 窗口/页面通过构造函数注入 VM，在隐藏代码里设置 `DataContext`。

## 8. 常见错误

1. **用旧字段式 `[ObservableProperty]`**：新代码一律用 `public partial` 属性写法（字段式会静默丢序列化字段，见上）。
2. **包版本 < 8.4 / 语言版本不足**：不支持 partial property 写法；语言版本需 `preview` 或 C# 14。
3. **在 VM 里 `new` 服务或 `Ioc.Default.GetService`**：隐藏依赖、破坏可测性。
4. **每文档/每次打开的 VM 注册成 `Singleton`**：状态串味、关闭后再打开报错。
5. **`CanExecute` 忘了失效**：属性变化后用 `[NotifyCanExecuteChangedFor]` 或 `NotifyCanExecuteChanged()`。

## 9. 参考

- MVVM Toolkit 概览 — https://learn.microsoft.com/dotnet/communitytoolkit/mvvm/
- ObservableProperty — https://learn.microsoft.com/dotnet/communitytoolkit/mvvm/generators/observableproperty
- RelayCommand — https://learn.microsoft.com/dotnet/communitytoolkit/mvvm/generators/relaycommand
- ObservableValidator — https://learn.microsoft.com/dotnet/communitytoolkit/mvvm/observablevalidator
- Messenger — https://learn.microsoft.com/dotnet/communitytoolkit/mvvm/messenger
- 8.4 发布说明（partial properties）— https://devblogs.microsoft.com/dotnet/announcing-the-dotnet-community-toolkit-840/
