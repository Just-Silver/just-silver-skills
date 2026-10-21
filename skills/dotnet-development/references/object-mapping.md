# 对象映射（object-mapping）

<!-- 职责：实体 / 领域模型 / 持久化模型 ↔ DTO / API 契约之间的对象映射。默认零配置走 Mapster 约定，只有需要自定义规则时才写配置。不写：业务规则与编排（design-principles.md）、DI 生命周期与 Options（framework-practices.md）。 -->

> 映射库固定为 **Mapster**，不引入第二个映射库，也不自研映射框架。

## 默认：零配置，直接映射

Mapster **开箱即用**：同名的同类型成员自动对齐，嵌套对象、集合（`List<T>` / 数组 / 字典 / `IEnumerable<T>` / `IReadOnlyList<T>` 等接口）、record、拍平（`Supervisor.Name` → `SupervisorName`）都自动递归处理。

所以**绝大多数实体 → DTO 转换不需要写任何配置**：

```csharp
// 成员同名同类型 —— 没有配置，没有配置类，没有 .Map(...)
return mapper.Map<ProductDto>(product);
return mapper.Map<List<ProductDto>>(products);
```

**只有在「目标的某个成员无法从同名同类型源成员取到值」或「要改变默认行为」时才写配置。** 先判默认映射够不够，不够再加一条；不要先建配置类再把默认行为抄一遍。

**不需要写的**（写了只是噪音，还会把旧拼写钉死在配置里）：

- 同名同类型成员：`.Map(d => d.Id, s => s.Id)` —— 自动。
- 源的额外成员：`InternalAuditNote` 只要目标 DTO 没声明该属性就不会被搬运，「不外发」由 **DTO 的形状**保证，不需要 `.Ignore(...)`（`Ignore` 的参数是目标成员，目标上不存在则根本写不出来）。
- 嵌套/集合类型：`NewConfig<ProductTag, ProductTagDto>()` 这种纯同构的空配置——除非你明确要把它纳入启动期校验（见「可选加固」）。

## 什么时候才写配置（可判定清单）

命中任一条才写配置，其余一律走约定：

| 触发条件 | 配置 |
|---|---|
| 目标成员要**计算/拼接**（`FullName = First + " " + Last`、`LineCount = Lines.Count`） | `.Map(d => d.FullName, s => s.FirstName + " " + s.LastName)` |
| 成员**改名**（`Sku` → `Code`）或类型不同 | `.Map(d => d.Code, s => s.Sku)` |
| 要**忽略**目标上的可写成员（不接收该值） | `.Ignore(d => d.X)` |
| 要锁成**白名单**（只映射显式声明的成员） | `.Map(...)` 逐条 + `.IgnoreNonMapped(true)` |
| 按源**条件**取值 | `.Map(dest, src, cond)` 多段，默认段放最后；条件命中时想跳过用 `IgnoreIf` |
| 目标只有**构造器 / record / 只读属性** | `.MapToConstructor(true)` 或 `.ConstructUsing(s => new D(...))` |
| 需要**双向**映射 / 反向 unflatten | `.TwoWays()`（**必须在后续 `.Map(...)` 之前调用**）/ `.Unflattening(true)` |
| DTO → 实体只覆盖**有值字段** | `.IgnoreNullValues(true)` |
| 带导航属性的实体**写回** | `.EntityFromContext(db)`（`Mapster.EFCore`） |
| 映射里要用**注入的服务** | `MapContext.Current.GetService<T>()` + `ServiceMapper` |

转换里出现**业务决策**（按状态折算金额、按等级改折扣、合并多来源算指标）时，那不是映射配置的事——放进具名对象，配置只做同构搬运。

## 硬规则：不手写逐属性赋值

```csharp
// ❌ 逐属性赋值：新增/改名一个属性就静默漏掉，编译、审查、日常测试都发现不了
return new OrderSummaryDto
{
    Id = order.Id,
    CustomerName = order.CustomerName,
    Total = order.Total,
    LineCount = order.Lines.Count,
};

// ✅ 交由 Mapster：默认约定即可，只有 LineCount 这类派生字段需要一条配置
return mapper.Map<OrderSummaryDto>(order);
```

同样禁止：`query.Select(o => new OrderDto { Id = o.Id, ... })` 逐字段拷贝、为每一对类型手写 `OrderMapper` / `ToDto()` 静态类。

### 常见辩解

| 辩解 | 事实 |
|---|---|
| 「手写有编译期检查，Mapster 改名会静默」 | 手写只检查**名字拼写**，不检查**漏字段**：给 DTO 加一个成员，编译器不会要你回去补赋值，那个字段就一直是默认值。想拿回这道保护，见「可选加固」——`RequireDestinationMemberSource` 把它变成启动期异常。 |
| 「就三四个字段，手写更快」 | 字段数是变化的输入；今天 4 个、明天 9 个，而漏掉的那一个不报错、不报警。 |
| 「多写一个配置类更清楚」 | 纯同构类型对不需要配置：配置只承载**偏离约定**的部分，否则等于把默认行为抄一遍。 |
| 「`Adapt` 走反射，性能差」 | 映射由表达式树编译成委托并缓存，还可在启动时 `Compile()` 预热；性能不是手写的理由。 |
| 「这次只是投影几个字段，不算映射」 | 判据是**输出是不是某个 DTO / 契约类型**：是，就走映射；连 DTO 都不产出（计数、匿名聚合）才不配。 |

## 选哪个 API

| 源的状态 | 用法 |
|---|---|
| 已物化（实体实例、`List<T>`） | 注入 `IMapper`：`mapper.Map<TDest>(src)` / `mapper.Map<List<TDest>>(list)`；未用实例配置时 `src.Adapt<TDest>()` 等价 |
| 写回已存在的对象 | `mapper.Map(src, dest)`（就地写，返回同一个实例） |
| 仍是 `IQueryable` | `query.ProjectToType<TDest>(config)` 后 `ToListAsync()`，只取需要的列 |
| 映射需要注入的服务 | `MapContext.Current.GetService<T>()`，需配合 `ServiceMapper` |

**`Adapt` 与 `IMapper` 的差别只在配置来源，不是“哪个能用”**：无参 `src.Adapt<TDest>()` 固定读 `TypeAdapterConfig.GlobalSettings`；`IMapper` 读它自己持有的那个 config 实例。项目**只用约定映射时两者等效**；一旦用了自定义 config 实例，无参 `Adapt` 就拿不到那些自定义规则——派生字段会**静默变成 0/null**，编译期毫无提示。这种情况改用注入的 `IMapper`，或显式传 `src.Adapt<TDest>(config)`。

## 需要自定义规则时：`IRegister` + 实例

```csharp
public sealed class OrderMappingConfig : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        // 只写偏离约定的部分：同名成员自动对齐，此处只有派生字段
        config.NewConfig<Order, OrderSummaryDto>()
            .Map(d => d.LineCount, s => s.Lines.Count);
    }
}
```

- **放置在**与目标 DTO 同一层（应用/契约层）。Domain 不引用 DTO，映射配置也不放进 Domain。
- **组装**（组合根，只做一次）：

```csharp
using Mapster;
using MapsterMapper;

var mapConfig = new TypeAdapterConfig();
mapConfig.Scan(typeof(OrderMappingConfig).Assembly);   // 或 Apply(register...)

builder.Services.AddSingleton(mapConfig);
builder.Services.AddScoped<IMapper>(sp => new Mapper(sp.GetRequiredService<TypeAdapterConfig>()));
```

- 配置里需要**注入服务**（`MapContext.Current.GetService<T>()`）时，才换成 `Mapster.DependencyInjection` 的 `AddScoped<IMapper, ServiceMapper>()`；它负责把 `IServiceProvider` 塞进映射上下文，并让 `mapper.Map(...)` 的生命周期跟随注入的服务。
- `AddMapster()` 只注册 `IMapper → Mapper`（Transient）并绑定 `TypeAdapterConfig.GlobalSettings`——它**不会**注册你自己 new 的 config 实例，也不提供服务注入（服务注入要用 `ServiceMapper`）。走了自己的 config 就必须自己注册 `IMapper`。
- 配置只在启动期构建一次：`Compile()` 之后再改配置会抛异常。不要在业务方法里 `new TypeAdapterConfig()`，也不要每次调用 `Fork` 出新配置。
- **配置按类型对生效，不随父类型传递**：父类型配了 `PreserveReference` / `MaxDepth` 等设置，子类型要同样的行为得单独配。

## 常用配方

| 需求 | 写法 |
|---|---|
| 拼接/派生字段 | `.Map(d => d.FullName, s => s.FirstName + " " + s.LastName)` |
| 不暴露内部字段 | 目标 DTO 不声明该属性即不映射；要锁成白名单则 `.IgnoreNonMapped(true)` + 显式 `.Map` |
| 更新实体（只覆盖有值字段） | `config.NewConfig<Dto, Entity>().IgnoreNullValues(true)`，再 `mapper.Map(dto, entity)` |
| 带导航属性的实体写回 | `dto.BuildAdapter().EntityFromContext(db).AdaptTo(entity)`（`Mapster.EFCore`，自动在导航集合里找已跟踪实体） |
| record / 只读构造器 | `.MapToConstructor(true)`，或 `.ConstructUsing(s => new D(s.Id, s.Name))` |
| 双向映射（含 unflatten） | `.TwoWays()`，**必须在后续 `.Map(...)` 之前调用** |
| 每次映射的运行时参数 | `poco.BuildAdapter().AddParameters("user", name).AdaptToType<Dto>()` + `MapContext.Current.Parameters["user"]` |
| 同对象图里的引用复用 / 防环 | `.PreserveReference(true)`；不支持的场景改用 `.MaxDepth(n)` |

## 可选加固：让「漏字段 / 改名」在启动期暴露

Mapster 不靠人看代码，而是提供配置校验：

```csharp
mapConfig.RequireDestinationMemberSource = true;   // 目标成员必须有来源或显式 Ignore
mapConfig.Compile();                               // 校验并预编译
```

**前提（容易踩空）：`Compile()` 只遍历已登记的类型对**，纯约定映射没登记就不在校验范围内。想让某对类型被这道保护覆盖，就显式写一行**空配置**：

```csharp
config.NewConfig<Product, ProductDto>();   // 不写 .Map：只把它纳入校验与预编译
```

- 放在组装点（启动即失败）或一条配置校验测试里；`IMapper.Config` 暴露的就是同一个实例。
- 只想校验部分类型对时用 `Compile` 的定向重载，别为了通过校验把 `Ignore` 撒一遍。

## 陷阱

- **映射要纯**：不在配置里查库、发 HTTP、写日志。`AfterMapping` 是逃生口，不是常规手段——它会让映射无法投影成 SQL。
- **投影路径**（`ProjectToType`）必须用真实数据库跑一次集成测试：内存测试证明不了“生成的 SQL 正确、结果完整”。官方文档对 EF 场景的 `ProjectToType` 同时给了用法和一条「先物化再投影」的警告，两者冲突时以项目里的集成测试结果为准。
- **`PreserveReference` 不支持 EF 查询投影**；`MaxDepth` 支持，但每层都会生成映射代码，深度别开大。
- **DTO → 实体写回前先确认字段所有权**：全量 `mapper.Map(dto, entity)` 会连带覆盖本不该改的字段（状态、审计列、内部备注）。只映射允许改的成员，`Ignore` 掉主键、审计列与不在编辑表单里的字段。Mapster 默认连**默认值也写入**：源没带该字段时，实体上的值会被清成 `0`/`null`/空串。
- **`mapper.Map(src, dest)` 默认整体替换目标上的集合，不做元素级合并**：给已跟踪实体写回时，导航集合会被换成源里的新集合，EF 可能按孤儿规则删掉旧子实体。要保留跟踪身份就 `Ignore` 该导航属性并在服务里按业务键同步（或让集合属性走 `[UseDestinationValue]` / 配置 `UseDestinationValue` 的“清空 + 填充”）。
- **映射同类型 / 聚合根会触发深拷贝与递归**：环形引用会栈溢出，需要 `PreserveReference` 或 `MaxDepth`，并且要逐类型对配置。

## 自检（看到这些就先改，再解释）

- 出现了 `new XxxDto {` 后面跟一串同名赋值。
- 出现了 `ToDto()` / `ToXxx()` / `XxxMapper` 这类只为搬运字段的静态方法。
- 出现了 `.Select(x => new XxxDto { ... })` 的逐字段拷贝。
- 同一个 DTO 在两处以上用不同的手写代码转换。
- 反过来：为**纯同构**类型对写了 `.Map(d => d.X, s => s.X)` 这类逐成员抄写，或给每对类型都建空配置类（除非有意纳入启动校验）。
- 有了自定义配置，调用点却用无参 `Adapt<T>()` 或没传 config 的 `ProjectToType<T>()`。

## 参考

- 仓库文档根：https://github.com/MapsterMapper/Mapster/tree/master/docs/articles （Basic usages / Configuration / Settings / Packages）
- DI 与 `ServiceMapper`：`docs/articles/packages/Dependency-Injection.md`；源码 `src/Mapster.DependencyInjection/`
- EF Core 写回与投影：`docs/articles/packages/EF-6-and-EF-Core.md`
- 配置校验与编译：`docs/articles/configuration/Config-validation-and-compilation.md`
