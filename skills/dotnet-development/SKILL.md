---
name: dotnet-development
description: Use when writing, modifying, or reviewing C# / .NET code in any project type (ASP.NET Core, WPF, WinForms, Avalonia, MAUI, Blazor, console, worker, class library) — designing classes and services, registering or resolving dependencies, choosing service lifetimes, diagnosing memory/handle growth in long-running or background services, structuring modules/layers, building MVVM ViewModels with CommunityToolkit.Mvvm, deciding whether an abstraction or design pattern is warranted, mapping entities to DTOs or API contracts — or when about to introduce a service locator, a god class, an abstraction "for architecture's sake", a hand-written INotifyPropertyChanged / ICommand / property-change UI wiring, or property-by-property entity↔DTO conversion, instead of the CommunityToolkit.Mvvm source generators and Mapster.
---

# .NET 开发规范

---

# 🛑 开发红区 —— 写代码前先读，命中即停

> **本节优先级高于本文档其余一切内容。** 以下问题会**静默**毁掉生产（内存/句柄只增不减、数据错乱、进程崩溃），而**编译器、常规工具、日常代码审查全都发现不了**——只有上线运行数周/数月后才爆。
>
> **命中任意一条：立刻停下来修，不要继续往下写。** 下列理由一律无效：「能跑就行」·「应该没事」·「我手动 `Dispose` 了」·「已经跑了几个月都正常」。

| # | 红线 | 为什么致命（静默） |
|---|------|-------------------|
| **1** | **从根容器反复解析实现 `IDisposable` 的瞬态对象**（`Singleton` 注入 `IServiceProvider`，在循环 / `Timer` 回调 / 后台服务里 `GetRequiredService`） | 实例被容器**强引用到进程退出**，内存/句柄只增不减。**手动 `Dispose()`、改成工厂注册都救不了**（均已实测）。官方原话：**不要用 `Transient` 注册 `IDisposable`** |
| **2** | **`catch (Exception) { }` 静默吞异常** | 故障被掩盖、日志无痕，最终在无关的地方以无关的形态爆发 |
| **3** | **`.Result` / `.Wait()` / `async void`** | 死锁与进程崩溃，通常只在生产并发下才露出（`async void` 仅框架回调 / `override` 这类签名不可改处例外） |
| **4** | **`HttpClient` 用错**：长期持有却不设 `PooledConnectionLifetime`，或频繁 `new` | DNS 不更新 / 端口耗尽，延迟数小时至数天才爆 |

**红线 1 的官方解法**：**不要用 `Transient` 注册 `IDisposable`**，二选一——让每轮 / 每批工作单元拥有一个**会被释放的 scope**（`IServiceScopeFactory.CreateAsyncScope()`），或用**工厂模式**由消费者释放（`AddTransient(sp => new X())` **不算**工厂模式，仍被追踪）。完整机制、实测数据与逐条改法见 `references/framework-practices.md`「🔴 可释放瞬态被容器强引用」——**命中红线 1 时必须去读它**。

> 本文档下方「其余反模式」表**不重复**本节条目，只收录不会静默致命的耦合/过度设计问题。

---

## Overview

开发或审查任何 C# / .NET 代码时，默认遵循本规范。最终目标**不是“模式最多”**，而是：

> **职责清晰、依赖明确、对象内聚、耦合可控、易于测试和演进。**

三条底线：依赖通过**构造函数显式注入**；高层依赖**抽象**而非具体实现；**不为展示架构而制造架构**。

规范对 Web、桌面（WPF/WinForms/Avalonia/MAUI）、控制台、类库、Worker **一视同仁**——“不是 Web”不是省略 DI、退化成静态类和 `new` 依赖的理由。

## 技术栈基线（统一约定，除非项目已明确另选）

- **DI 容器**：一律 **Microsoft.Extensions.DependencyInjection**（经 `Host.CreateApplicationBuilder` / `Host.CreateDefaultBuilder` 或 `ServiceCollection`）；**不引入** Autofac / Unity / Prism 等第三方容器，也不自研容器。
- **基础设施**：优先 **Microsoft.Extensions.\*** 官方包——`Hosting`、`Configuration.*`、`Options.*`、`Logging.*`、`Http`（`IHttpClientFactory`）、`Http.Resilience`、`Caching.*`、`DependencyInjection`。日志、配置、HTTP、缓存、健康检查都走这些抽象。
- **MVVM**：一律 **CommunityToolkit.Mvvm**；`[ObservableProperty]` **必须**用 partial property 新写法 `public partial string? Name { get; set; }`，**禁止**旧字段式 `private string? _name;`。详见 `references/mvvm-communitytoolkit.md`。
- **对象映射**：一律 **Mapster**——实体 / 领域模型 ↔ DTO、API 契约之间**不手写逐属性赋值**。Mapster **开箱即用**：成员同名同类型时零配置（含嵌套、集合、record），**只在需要计算字段 / 改名 / 忽略 / 写回等自定义规则时**才写 `IRegister` 配置。详见 `references/object-mapping.md`。
- **时间/测试**：时间用 `TimeProvider`；测试用 `Microsoft.Extensions.TimeProvider.Testing`。
- **服务生命周期**：按**需求**选，不是按偏好——多数容器默认 `Transient`；`Singleton` 的正当理由是「全局共享」或「创建昂贵」（**不要无理由地给无状态服务用 `Singleton`**）；**可释放对象必须有释放边界**（见红区 1 与 `references/framework-practices.md` 第 1 节「DI 生命周期」及其下「可释放对象（`IDisposable`）的归宿」）。

## When to Use

- 编写 / 修改 / 审查任意 C# / .NET 代码（含 Web、桌面、控制台、类库、后台服务）
- 写 / 改 ViewModel、XAML 数据绑定、`ICommand`，或需要在属性变化时联动 UI（**必读** `references/mvvm-communitytoolkit.md`，先看下方「特性速查」定位）
- 设计类、服务、模块分层；注册或解析依赖；选择 `Singleton` / `Scoped` / `Transient`
- 实体 / 领域模型 ↔ DTO / API 契约的转换（**必读** `references/object-mapping.md`），或正在写逐属性赋值的映射代码
- 纠结“要不要抽接口 / 上工厂 / 建继承体系 / 拆服务 / 用某个设计模式”
- 重构、代码审查，或排查“难测试 / 难维护 / 改动牵连大”的设计

**不适用**：非 .NET 技术栈；纯格式/命名等风格细节（见 `references/design-principles.md` 末节）。

## 路由（MVVM 命中即读；其余按需，不要全读）

| 场景 | 读取 |
|------|------|
| 核心原则、SOLID、抽象/继承、模式取舍、开发顺序、审查标准 | `references/design-principles.md` |
| DI 生命周期、Options、`ILogger<T>`、`IHttpClientFactory`、异常、async、数据访问 | `references/framework-practices.md` |
| **对象映射**：实体 ↔ DTO / API 契约、写回实体、`ProjectToType` 投影、需要自定义规则时才写配置 → **命中即读** | `references/object-mapping.md` |
| WPF / WinForms / Avalonia / 控制台 / Worker 的 Composition Root、组装与项目结构 | `references/app-composition.md` |
| **MVVM（任何 UI 框架）**：写 / 改任一视图（XAML/AXAML/code-behind）、ViewModel、数据绑定、`ICommand` 或输入校验 → **命中即读，先读本行**（不等“按需”） | `references/mvvm-communitytoolkit.md` |

> **MVVM 只有一个权威出口：`references/mvvm-communitytoolkit.md`。** `app-composition.md` 里的「MVVM 要点」只是**摘录速查**，覆盖不了全部特性（缺 `[NotifyPropertyChangedFor]`、`CanExecute` 刷新细节、Messenger 用法等）；**读过它不算读过 MVVM 规范**，不得据此跳过引用文件。

## CommunityToolkit.Mvvm 特性速查（写 VM 前扫一眼，禁止手写样板）

| 需求 | 用特性 |
|------|--------|
| 可通知属性 | `[ObservableProperty]` + `public partial T X { get; set; }`（禁旧字段式） |
| 属性变更副作用（**同对象内**用它，别订阅自己的 `PropertyChanged`） | 生成器分部钩子 `partial void OnXxxChanged(T value)` / `OnXxxChanging(T oldValue, T newValue)` |
| 命令 | `[RelayCommand]`（异步方法带 `CancellationToken`） |
| 属性变 → 通知依赖属性 | `[NotifyPropertyChangedFor(nameof(Other))]` |
| 属性变 → 刷新命令可用性 | `[NotifyCanExecuteChangedFor(nameof(SaveCommand))]` |
| 输入校验 | 继承 `ObservableValidator` + `[NotifyDataErrorInfo]` + DataAnnotations |
| 属性变 → 广播消息 | `[NotifyPropertyChangedRecipients]`（配 `ObservableRecipient`） |
| 跨 VM 通信 | 注入 `IMessenger`（`WeakReferenceMessenger.Default`，DI 注册一次） |

> 本表只做索引，防止“不知道该用哪个特性”这类漏读；签名、参数、约束与版本要求一律以 `references/mvvm-communitytoolkit.md` 为准。

## 其余反模式（命中即改，不要自我辩解）

> 红区 4 条见文首「🛑 开发红区」，此处**不重复**。本表收录的是**不会静默致命**的耦合与过度设计问题。

| 反模式 | 为什么错 | 改法 |
|--------|----------|------|
| 类内 `new` 业务依赖（仓储、邮件、HttpClient…） | 把代码焊死在某个实现上，无法替换/测试 | 构造函数注入抽象；基础设施在 Composition Root 组装 |
| Service Locator（`IServiceProvider.GetService`、`Ioc.Default`、静态容器） | 依赖被隐藏，错误从编译期推迟到运行期 | 构造函数注入；确需运行期选择时用抽象工厂/策略 |
| 引入第三方 / 自研 DI 容器 | 与官方生态脱节、多套生命周期语义 | 统一 `Microsoft.Extensions.DependencyInjection`（Generic Host / `ServiceCollection`） |
| MVVM 手写 `INotifyPropertyChanged` 样板；`[ObservableProperty]` 用旧字段写法 `private string? _name;` | 字段式生成的属性对**同编译内其它源生成器不可见**（如 STJ 源生成），序列化会**静默丢字段**（写出 `{}`） | CommunityToolkit.Mvvm，用 `[ObservableProperty] public partial string? Name { get; set; }`；**VM 之外的配置/序列化类型同样适用** |
| 视图（XAML/AXAML/code-behind）承载业务或状态逻辑：事件处理器里改模型、在 code-behind 手动 `IsEnabled`/可见性联动、`Click=` 里做业务、直接 `new` 服务 | UI 与业务耦合、无法单测、状态通知易漏 | code-behind 只做 `InitializeComponent`、设 `DataContext`、纯视图初始化（焦点/动画/窗口行为）；交互走 `[RelayCommand]` + 绑定，联动走生成钩子 / 通知特性 |
| 手写 `ICommand` / 自造命令；**同对象内**联动用手写 `PropertyChanged` 订阅或手动刷新 `CanExecute`；输入无校验、或校验不门禁命令 | 样板易漏通知、命令可用性不刷新、按钮重复点击、非法输入仍可提交；且绕过源生成器 | `[RelayCommand]`（异步带 `CancellationToken`，默认执行期禁用防重复点击）；联动优先 `OnXxxChanged` 钩子 + `[NotifyPropertyChangedFor]` / `[NotifyCanExecuteChangedFor]`（**仅跨对象**才订阅）；校验 `ObservableValidator` + `[NotifyDataErrorInfo]`，命令用 `HasErrors` 门禁 |
| VM / 视图直接调用 `TopLevel`、`StorageProvider`、`Application.Current`、`File.*`、`MessageBox` 等平台/宿主 API | 无法单测、耦合宿主、跨平台迁移受阻 | 抽 `IFilePicker` / `IDialogService` / `IClipboard` 之类接口，在组装点绑定实现、构造注入 |
| 静态可变状态 / 全局上下文 / 静态工具类承载业务 | 隐式全局状态，并发与测试噩梦 | 无状态服务 + DI；纯函数工具才可静态 |
| 手写实体 ↔ DTO 转换：逐属性 `new Dto { X = e.X }`、查询里逐字段 `Select` 拷贝、每对类型一个 `ToDto()`/`XxxMapper` | 属性改名不报错、新增字段静默漏、重复代码逐处漂移；漏字段要到线上才发现 | **Mapster**：默认**零配置**直接 `mapper.Map<T>()`（同名成员自动对齐，含嵌套/集合）；只有派生字段、改名、忽略、写回等自定义规则才加一条 `NewConfig`。见 `references/object-mapping.md` |
| 应用/业务层直接依赖 `DbContext`、`SqlConnection`、`HttpClient`、`DateTime.Now`、文件系统 | 高层耦合具体基础设施 | 通过接口/边界接入；时间用 `TimeProvider`，HTTP 用 `IHttpClientFactory` |
| 万能类：`XxxManager` / `XxxHelper` / `XxxUtil` / 超长 `Service` | 职责发散，一个类多个变化原因 | 按职责拆分，让行为回到所属对象 |
| 每个类都造 `IXxx` + `Xxx` | 只为“像 DI”而加文件，无替换价值 | 只在真实边界/可替换/可测试处抽接口 |
| 为架构而架构：无实际用途的 `Factory`/`Handler`/`Wrapper`/`BaseService`/`Repository` 层 | 增加跳转层级与维护成本，收益为零 | 简单实现能解决就不加中间层；出现第二实现/变化点再加 |
| `Singleton` 捕获 `Scoped`/`Transient` 依赖（captive dependency） | 短生命周期被提升为单例，串请求状态 | 按实际生命周期注册，长生命周期服务不得捕获更短的依赖；若被捕获的是可释放 `Transient`，属红区 1 |
| `Console.WriteLine` / 直接依赖具体日志实现 | 无结构、无法分级过滤、业务耦合基础设施 | 注入 `ILogger<T>`，结构化日志 |
| `Environment.GetEnvironmentVariable` 散读配置 | 魔法字符串、无校验、无法热更新 | Options 强类型绑定 + 校验 |

> **Service Locator 的例外**：组合根 / 框架适配层（无法构造函数注入，如应用基类按运行时类型解析主窗口、导航按类型解析页面）可持有 `IServiceProvider`，但**必须在 XML 注释写明理由**；业务代码仍一律禁止（构造函数注入 / 抽象工厂 / 策略）。

## 开发顺序（正向配方）

```
理解职责 → 明确对象与边界 → 明确依赖 → 通过 DI 组装 → 实现业务行为 → 保持对象内聚 → 再考虑扩展性
```

**不要**先建一堆目录、接口和抽象，再去找它们存在的理由。

## 提交前自检（REQUIRED）

- [ ] 有可以被组合替代的继承吗？（默认组合 + 注入 + 策略/委托/接口）
- [ ] 有类在内部 `new` 外部业务依赖吗？
- [ ] 有隐藏依赖：Service Locator、全局静态状态、静态可变字段？
- [ ] 有职责过多的类 / 过大的接口 / 超长方法？
- [ ] 有本该属于对象、却被塞进外部 Service 的业务逻辑？
- [ ] 有为了模式而模式的抽象层（无第二实现、无变化点）？
- [ ] 生命周期选择是否与依赖生命周期匹配？有无 captive dependency？
- [ ] 循环 / `Timer` / 后台服务里，是否从根容器解析了实现 `IDisposable` 的瞬态对象？（会被强引用到进程退出；手动 `Dispose` 救不了）
- [ ] 外部依赖（DB/HTTP/时间/文件）是否可替换、可单测？
- [ ] 实体 ↔ DTO 转换是 `mapper.Map` / `ProjectToType`（纯同构不必写配置），还是散落的手写逐属性赋值？
- [ ] 异常是否被真正处理或向上抛出，而非静默吞掉？
- [ ] 配置走 Options、日志走 `ILogger<T>` 了吗？

**涉及 UI / MVVM 时追加（视图、ViewModel、命令、绑定、校验有改动就跑一遍）：**

- [ ] 视图（XAML/AXAML/code-behind）里有没有业务或状态逻辑？（code-behind 只允许 `InitializeComponent`、设 `DataContext`、纯视图初始化）
- [ ] 属性联动是用生成钩子（`OnXxxChanged`）与通知特性，还是手写 `PropertyChanged` 订阅？（只有**跨对象**联动才订阅）
- [ ] 每个交互都是带 `CanExecute` 的 `[RelayCommand]` 吗？状态变化有 `[NotifyCanExecuteChangedFor]` 失效吗？
- [ ] 用户输入经过 `ObservableValidator` 校验、且命令用 `HasErrors` 门禁了吗？
- [ ] `TopLevel`/`StorageProvider`/`Application.Current`/文件与对话框等平台 API，是否经接口注入而非在视图/VM 直接调用？

## Common Mistakes

- **把“企业级”当目标**：上来就分层 + 工厂 + 管理器 + 仓储接口。先问“变化点在哪、谁需要这个抽象”，没有答案就别加。
- **把 OOP 理解成“到处建对象”**：为了面向对象硬造复杂领域模型，同样有害；对象职责应来自真实业务。
- **DI = 万物接口化**：接口只表达真实抽象与边界，不是文件数量竞赛。
- **桌面/控制台项目没有 Composition Root**：WPF/Avalonia/WinForms/控制台同样应有一个组装点（Generic Host 或 `ServiceCollection`），详见 `references/app-composition.md`。
- **只关注“能跑”**：设计时就考虑依赖可替换、时间可控制、IO 可隔离、规则可独立测试。
