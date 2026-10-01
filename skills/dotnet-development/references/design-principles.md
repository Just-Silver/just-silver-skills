# .NET 设计原则（design-principles）

> 本文件是 `dotnet-development` 的核心原则与取舍标准。凡写/审 .NET 代码都适用。
> 框架级实践（生命周期、Options、日志、HTTP、异常、async）见 `framework-practices.md`；组装与项目结构见 `app-composition.md`。

## 核心原则

开发 .NET 项目时始终优先遵循：

- **面向对象设计**：让对象承担明确职责，通过对象协作完成业务，而不是堆积过程式代码。
- **组合优于继承**：优先用组合、依赖注入、接口协作复用行为；除非确实存在稳定且合理的 `is-a` 关系，否则不要为复用代码建立继承体系。
- **依赖倒置**：高层业务逻辑不依赖具体实现，而依赖抽象。
- **依赖注入优先**：对象需要的依赖通过构造函数注入，避免在类内部主动 `new` 业务依赖。
- **单一职责**：一个类应有清晰、单一的变化原因，避免承担多个领域职责的“万能类”。
- **高内聚、低耦合**：相关行为和数据尽量集中在合适的对象中，对外暴露最少必要的依赖。
- **可测试性优先**：设计时应天然便于替换依赖和单测，而不是开发完再强行加可测试性。

## 面向对象设计

不要把业务逻辑简单堆积在：

- `Service` 中的超长方法
- `Manager`、`Helper`、`Util` 等万能类
- 静态方法
- 全局状态
- 大量 `if/else` 或 `switch`
- 数据对象 + 外部过程式代码

当某对象拥有某项业务行为时，优先让行为属于该对象，而不是全部放到外部服务里。

不要：

```csharp
orderService.CalculateTotal(order);
orderService.Cancel(order);
orderService.Pay(order);
```

合适的领域模型中应优先考虑：

```csharp
order.CalculateTotal();
order.Cancel();
order.Pay();
```

但**不要为了“面向对象”而强行制造复杂的领域对象**。对象职责应来源于实际业务，而不是设计形式。

## DI 与依赖管理

### 构造函数注入（默认）

```csharp
public sealed class OrderService
{
    private readonly IOrderRepository _repository;
    private readonly TimeProvider _clock;

    public OrderService(IOrderRepository repository, TimeProvider clock)
    {
        _repository = repository;
        _clock = clock;
    }
}
```

避免：

```csharp
public class OrderService
{
    public void Execute()
    {
        var repository = new SqlOrderRepository(); // 焊死实现
    }
}
```

类不应负责自行创建它所依赖的外部基础设施。

### 避免隐藏依赖

不要通过以下方式隐藏依赖：

```csharp
ServiceLocator.Get<IOrderRepository>();
Global.Current.Repository;
SomeStaticHelper.DoSomething();
```

除非该类型本身就是明确设计的无状态纯工具，否则不要用静态类绕过正常依赖关系。

### DI ≠ 万物接口化

不要机械地为每个类创建 `IUserService` + `UserService` 仅为满足 DI。以下情况可直接注入具体类型：

- 类型是明确的内部实现
- 不存在替换需求
- 不属于需要隔离的边界
- 引入接口不会带来实际设计价值

接口主要用于表达**真正的抽象和边界**，而不是增加文件数量。

## 抽象与边界

抽象应由**使用方需要的行为**决定，而不是由具体实现决定。优先定义最小能力：

```csharp
public interface IEmailSender
{
    Task SendAsync(string recipient, string subject, string body, CancellationToken ct);
}
```

而不是暴露包含大量无关能力的接口：

```csharp
public interface IEmailService
{
    Task SendAsync(...);
    Task DeleteAsync(...);
    Task ConfigureAsync(...);
    Task GetStatisticsAsync(...);
    Task ExportAsync(...);
}
```

避免为“架构完整”提前创建大量没有实际用途的抽象层。

## 继承

默认优先：**组合、依赖注入、策略、委托、接口**，而不是 **基类、子类、多层继承**。

只有在关系稳定且语义明确（`Derived is a Base`）时才用继承。**不要仅仅因为两个类存在重复代码就建立继承关系。**

## SOLID

- **S 单一职责**：职责清晰，避免万能类。
- **O 开闭**：扩展新行为优先通过组合、策略、实现替换完成，而不是不断修改巨大条件分支。
- **L 里氏替换**：子类型必须真正满足父类型契约。
- **I 接口隔离**：接口保持小而明确，只暴露使用者真正需要的能力。
- **D 依赖倒置**：业务逻辑依赖抽象，具体基础设施通过 DI 提供。

**不要为了形式上的 SOLID 引入不必要的抽象、工厂、泛型或层次结构。**

## 条件分支与多态

当业务存在多个**稳定且可扩展**的行为变体时，优先策略 / 多态 / 组合：

```csharp
public interface IPricingStrategy
{
    decimal Calculate(Order order);
}
```

比不断扩展 `switch (order.Type) { ... }` 更适合长期演进。但简单、固定、不会扩展的判断**不需要**为了“多态”而复杂化。

## 类与方法设计

优先：`sealed`（无继承需求时）、`readonly`（依赖/状态不被意外重新赋值）、小而明确的方法、明确的参数与返回值、适合场景的不可变数据结构、`CancellationToken`、`async/await`。

避免：超大类、超长方法、深层嵌套、参数过多、布尔参数驱动大量不同逻辑、魔法字符串/数字、隐式全局状态。

当一个类开始承担明显不同的职责时，应**拆分**，而不是继续加功能。

## 状态管理

尽量减少共享可变状态。优先：局部状态、对象自身状态、明确生命周期、通过依赖传递状态。

谨慎使用：`static mutable state`、Singleton 可变状态、全局缓存、全局上下文。

若使用 Singleton，必须确认其生命周期与线程安全设计合理，而不是因为“方便访问”。

## 生命周期

正确选择 `Singleton` / `Scoped` / `Transient`，基于实际生命周期与线程安全要求。不要为减少实例创建而无脑用 Singleton。**尤其避免 Singleton 直接持有更短生命周期的依赖（captive dependency）。** 详见 `framework-practices.md`。

## 异常与错误处理

异常用于表达真正异常的情况，不要当作普通控制流。

不要为了“防止崩溃”到处 `try { } catch (Exception) { }` 然后静默吞掉。异常必须：被真正能处理它的层处理、或继续向上抛出、必要时补上下文、保留原始异常信息。**不要无意义地捕获后重新包装异常。**

## 日志

日志应描述：发生了什么、关键上下文是什么、为什么需要关注。

避免 `Console.WriteLine("出错了")`。优先结构化日志与依赖注入的 `ILogger<T>`。不要在业务代码中直接依赖具体日志实现。

## 配置

配置通过 .NET Configuration / Options 机制管理。避免业务代码直接读 `Environment.GetEnvironmentVariable(...)`，也不要把配置散落在大量静态字段中。需要配置时优先使用强类型 Options。

## 数据访问

业务逻辑不要直接依赖具体数据库 API、SQL 连接或 ORM 细节。应明确区分：**业务逻辑 / 应用逻辑 / 基础设施**。具体数据库、网络、文件系统属于基础设施依赖，应通过明确边界接入。

> 注意：仓储（Repository）不是必需品。若 ORM 已经提供了工作单元与查询抽象，再套一层一对一转发的 `IRepository` 只会增加跳转。**只有在确实需要隔离持久化实现、需要替换、或需要为测试提供接缝时才引入。**

## 可测试性

设计时默认考虑：依赖是否可替换？时间是否可控？外部 IO 是否可隔离？业务规则是否可独立测试？

需要时间时抽象时间来源（现代 .NET 用 `TimeProvider`），而不是到处直接调用 `DateTime.Now`。需要外部服务时通过 DI 隔离。

不要为了测试而给生产代码加大量特殊入口；正确的设计本身应具备可测试性。

## 现代 .NET 优先

使用当前推荐方式：`async/await`、`CancellationToken`、`IOptions<T>`、`ILogger<T>`、Generic Host / DI、`HttpClient` 与 `IHttpClientFactory`、`System.Text.Json`、`record` / `record struct`、`required`、nullable reference types。

但不要为了用新特性而用新特性，以清晰度和实际需求为准。

## 设计取舍

不要机械套用设计模式。实现功能前优先自问：

```
职责是谁的？
这个对象为什么需要这个依赖？
这个依赖应该由谁提供？
变化点在哪里？
这个行为是否应该属于对象本身？
是否真的需要抽象？
是否真的需要继承？
是否可以通过组合解决？
```

**禁止为了展示架构而制造架构。** 简单实现已能满足需求时，不要为“企业级架构”额外增加 `Factory`、`Manager`、`Handler`、`Wrapper`、`Adapter`、`Repository`、`BaseService`、`BaseManager` 等没有实际价值的中间层。

## 开发顺序

```
理解职责 → 明确对象与边界 → 明确依赖 → 通过 DI 组装 → 实现业务行为 → 保持对象内聚 → 再考虑扩展性
```

不要先创建大量目录、接口和抽象，再寻找它们存在的理由。

## 代码审查标准

完成后主动检查：

1. 是否存在可以被组合替代的继承？
2. 是否存在类内部 `new` 外部业务依赖？
3. 是否存在隐藏依赖、Service Locator 或全局状态？
4. 是否存在职责过多的类？
5. 是否存在过大的接口？
6. 是否存在可以提取为对象行为、却被放在外部 Service 中的业务逻辑？
7. 是否存在为了模式而模式的抽象层？
8. 是否仍然能方便地替换外部依赖并测试？

最终目标不是“模式最多”，而是：**职责清晰、依赖明确、对象内聚、耦合可控、易于测试和演进。**

## 代码风格（补充，非重点）

- 命名、格式、`var` 使用、`using` 位置等遵循项目现有 `.editorconfig` 与团队约定；无约定时参照 [.NET Coding Conventions](https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions)。
- 能用分析器（Roslyn analyzers / `.editorconfig`）强制的风格，交给工具，不要写进规范靠人记。
