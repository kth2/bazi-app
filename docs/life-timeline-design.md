# 人生时间线（2甲子 · 0-120岁）技术方案

> 状态：设计稿，待确认后实施。本文只定方案与数据结构，不含完整实现。

## 0. 先修正一个前提

需求里写的是 TypeScript 类型定义，但本仓库是 **Flutter / Dart**
（`pubspec.yaml` + `lib/**.dart`，无任何 TS）。下面给出的是等价的 Dart 定义。
若原意是要另起一个 Web/React 前端，那是另一件事，需先确认。

## 1. 两个实测事实（决定了架构）

以 `丙辰 壬辰 丁巳 癸卯`（起运 10.1 岁）实测：

| 项目 | 实测值 | 影响 |
|---|---|---|
| `ChartService` 返回的大运数 | **8 步（11-90 岁）** | 覆盖不到 120 岁，须扩到 12 步 |
| 每年跑完整 `ReasoningReport` | **7.5 ms** | 120 年约 900ms，扫全生会卡顿 |
| 每年只跑「引动+事件」精简路径 | **0.1 ms** | 120 年约 12ms，可即时全扫 |

**结论**：应期（`YingQiEngine`）排期占了 98% 的成本。
时间线的自动推荐走**精简路径**；应期细节等用户点开某一年时**按需计算**。

### 必要的前置改动

`lib/core/engine/chart_service.dart`

```dart
static const int _decadeCount = 8;   // → 12
```

12 步覆盖起运+120 年，再按 120 岁截断。0 岁到起运之间已有
`ChartResult.preDaYunYears`（小运期，实测 10 条），时间线首段直接复用。

## 2. 模块拆分

```
lib/core/timeline/
  life_span.dart          年龄↔公历↔大运/流年 的坐标换算（纯函数，可测）
  timeline_event.dart     LifeEvent 模型：类型/强度/区间/来源/备注
  event_catalog.dart      事件类型注册表（可配置，含敏感标记）
  timeline_scanner.dart   引擎 → 自动推荐事件（走精简路径）
  timeline_store.dart     用户增删改的持久化（drift，用户数据）

lib/features/timeline/
  timeline_page.dart      页面骨架 + 缩放/滚动状态
  timeline_painter.dart   CustomPainter：大运色块 + 流年刻度 + 事件标记
  timeline_geometry.dart  像素↔年龄 映射、命中测试（被 painter 与拖拽共用）
  event_palette.dart      工具栏（可拖出的事件图标）
  event_editor_sheet.dart 编辑/删除/调区间/调强度
  timeline_settings.dart  敏感类别开关 + 免责声明
```

依赖方向：`features/timeline` → `core/timeline` → `core/analysis`。
**反向禁止**，理由见第 7 节。

## 3. 数据结构（Dart）

### 3.1 坐标：一切以「年龄」为轴

```dart
/// 时间线的坐标系。年龄是主轴，公历年份是派生量。
class LifeSpan {
  final ChartResult chart;
  final int maxAge; // 120

  /// 起运年龄（含小数），0..qiYunAge 属小运期。
  double get qiYunAge => chart.qiYunAge;

  /// 年龄 → 公历年（虚岁口径，与 FlowYearData.age 一致）。
  int calendarYearAt(double age);

  /// 年龄 → 所在大运，未起运或超出范围返回 null。
  DecadeData? decadeAt(double age);

  /// 年龄 → 所在流年。
  FlowYearData? flowYearAt(double age);
}
```

### 3.2 事件锚点：存年龄区间，不存索引

```dart
/// 事件在时间线上的位置。
///
/// 存年龄（double）而不是大运下标或数组位置：出生时间一旦被修正、
/// 或大运步数从 8 改到 12，索引全部失效，而年龄区间不受影响，
/// 可随时重新解析到新的大运/流年。
class TimelineAnchor {
  final double startAge;
  final double endAge;   // == startAge 表示单点事件

  bool get isSpan => endAge > startAge;
}
```

### 3.3 事件本体

```dart
enum EventIntensity { low, medium, high }

/// 事件从哪来 —— 决定它能否被重算覆盖。
enum EventOrigin {
  suggested, // 引擎推荐，重算时可被替换
  userMoved, // 引擎推荐后被用户拖动过，重算时保留
  userAdded, // 用户手工添加，引擎绝不触碰
}

class LifeEvent {
  final String id;
  final String kindId;          // 见 EventCatalog
  final TimelineAnchor anchor;
  final EventIntensity intensity;
  final EventOrigin origin;

  /// 引擎给出的把握度 0..1（用户添加的为 null）。
  final double? confidence;

  /// 推荐理由链，复用 EventCandidate.basis。
  final List<String> basis;

  final String note;            // 用户备注
  final DateTime createdAt;
  final DateTime? updatedAt;
}
```

### 3.4 事件类型注册表（可配置）

```dart
enum EventSensitivity {
  normal,   // 默认显示
  guarded,  // 默认关闭，需用户主动开启
}

class EventKind {
  final String id;              // 'career.promotion'
  final String label;           // 升职
  final String domain;          // 复用 EventDomain：事业/财富/婚姻/学业发展/健康
  final String icon;            // 图标名
  final bool defaultSpan;       // 天然是区间（如财运高峰）还是单点（如结婚）
  final EventSensitivity sensitivity;
  final String? disclaimer;     // guarded 类必填
}
```

`EventCatalog` 是一张常量表 + 用户覆盖层（开关状态存本地）。

## 4. 事件清单与现有引擎的对应

现有 `EventDomain.subtypes` 已覆盖大半。需求清单的映射与缺口：

| 需求事件 | 现有子类型 | 缺口 / 判据 |
|---|---|---|
| 重要考试、金榜题名 | 学业发展·考试资格 / 文书学业 | 印星得力 + 官印相生；已有 |
| 出国留学 | — | **新增**：驿马 + 印星（神煞已算在 `PillarData.shenSha`） |
| 恋爱/正缘、结婚 | 婚姻·婚恋成合 | 已有（男看财、女看官，已按性别分流） |
| 离婚风险 | 婚姻·感情生变 / 配偶宫动 | 已有，但须标 **guarded** |
| 生子 | 婚姻·子女之事 | 判据待确认：男以官杀为子、女以食伤为子 |
| 搬家/买房 | — | **新增**：印星（宅）+ 财星，或 驿马动 |
| 升职 | 事业·职位晋升 | 已有 |
| 创业 | 事业·创业自立 | 已有 |
| 换工作/跳槽 | 事业·职务变动 / 离职转换 | 已有 |
| 财运高峰 | 财富·收入增益 | 已有，天然是**区间** |
| 破财风险 | 财富·破财损耗 | 已有；`normal`，**不**默认关闭 |
| 贵人相助 | — | **新增**：天乙贵人/太极贵人 神煞 + 印星被引动 |
| 远行/出差/移民 | 事业·迁移变动 | 部分有；移民需 驿马 + 冲提纲 |
| 健康需注意 | 健康·各子类 | 已有 |
| 手术风险窗口 | — | **新增**，**guarded**：日主受重克 + 刑冲 |
| 寿元参考区间 | — | **新增**，**guarded**，见第 5 节 |
| 名气提升 | — | **新增**：食伤透显 + 官星 |
| 学习新技能/转型 | 学业发展·技艺才华 / 进修拓展 | 已有 |
| 官司风险 | 事业·职场是非 | 部分有；需加 官杀+刑 的专门判据，**guarded** |

新增判据都写成 `_EventRule` 风格的表项，与现有 `EventInferenceEngine`
同一套 stance/effect 机制，不另起炉灶。

## 5. 敏感事件的处理边界

按需求：离婚、大病/手术、寿元、官司默认关闭，需主动开启。**这四类就是全部**
——「破财风险」是 `normal`，照常显示，不进 guarded 名单（已确认）。除此之外：

**寿元一项不做「预测死亡年份」。** 引擎不会输出某一年为终点，也不会给出
「寿元 X 岁」。开启后只会把「日主受克极重、且多重刑冲叠加」的**年龄区间**
标为 *需特别注意健康的年份*，与其他健康事件同一视觉层级，不做特殊强调。

理由不只是措辞：单点死亡预测既无法验证，也会让一个参考工具变成对用户有
实际伤害的断言。区间式的健康提示保留了信息，去掉了伤害。

强制文案（开启任一 guarded 类别时常驻显示）：

> 以下标记依传统命理规则推算，仅供参考，不构成医疗、法律或财务建议。
> 命理无法预知具体事件，如有健康疑虑请就医。

实现上：`EventSensitivity.guarded` 的类型，
- 默认 `enabled = false`；
- 开启需经一次确认弹窗（读过免责声明）；
- 渲染时颜色饱和度低于普通事件，不用红色警示色。

## 6. 时间线组件实现思路

### 6.1 不要用 `InteractiveViewer`

`InteractiveViewer` 做的是二维矩阵变换，和 `Draggable` 抢手势，且拖放时
要把全局坐标反变换回内容坐标才能命中测试，容易出错。

改用：**一个自管的 `(pxPerYear, offset)` 状态**，平移和缩放都走同一个
`GestureDetector`。

> **P2 更正**：本节原先写的是「横向 `SingleChildScrollView` 负责平移，
> 滚动惯性免费获得」。这是错的，实现时已改。`Scrollable` 会把横向拖拽
> **连同双指拖拽一起**认领掉，捏合手势因此永远到不了 scale recognizer，
> 双指缩放直接失效。平移和缩放必须由同一个识别器处理。

```dart
// 缩放只改一个标量；平移只改另一个。两者都不经过 Scrollable。
double pxPerYear;           // 缩放级别
double offset;              // 已滚过 0 岁的像素数
double get contentWidth => pxPerYear * maxAge;
double xForAge(double age) => age * pxPerYear - offset;
double ageForX(double x)   => (x + offset) / pxPerYear;
```

好处：命中测试只是一维除法；手势没有归属之争。代价是惯性、滚动条、键盘
滚动都要自己来（P2 只做了鼠标滚轮 + 缩放按钮，惯性暂缺）。

平移与缩放合并成一句话：**手指按下时那一岁，始终留在手指下面**。
`onScaleStart` 记下这一岁，`onScaleUpdate` 用它反解 offset — 单指拖动
是 `scale == 1` 的退化情形，不需要单独一条代码路径：

```dart
// 手势开始
anchorAge = ageForX(details.localFocalPoint.dx);
// 手势更新（相对手势起点的几何，不是上一帧，否则缩放会累乘）
pxPerYear = (startPxPerYear * details.scale).clamp(minPx, maxPx);
offset    = anchorAge * pxPerYear - details.localFocalPoint.dx;
```

### 6.2 三档 LOD（缩放决定画什么）

| pxPerYear | 显示 |
|---|---|
| < 4 | 只画大运色块 + 每 10 年标注，事件聚合成簇 |
| 4-16 | 大运色块 + 每 5 年刻度，事件分开 |
| > 16 | 逐年刻度 + 干支 + 事件全展开 |

避免 120 年 × 每年多事件时一次性画上千个 widget。

### 6.3 绘制与交互分层

- `CustomPainter` 画**静态层**：大运色块、流年刻度、网格。
- 事件标记用真实 widget（`Positioned`）叠在上层 —— 因为要能点、能拖、能长按。
  数量可控（LOD 已聚合），不至于爆炸。
- `timeline_geometry.dart` 同时被 painter 和拖放逻辑引用，保证两者坐标一致。
  这是最容易出 bug 的地方：**一份映射，两处使用**。

### 6.4 拖放

- 工具栏项是 `Draggable<EventKind>`。
- 时间线整体是一个 `DragTarget<EventKind>`，`onAcceptWithDetails` 拿到全局
  坐标 → `RenderBox.globalToLocal` → `ageForX` → 按当前 LOD 吸附到
  最近的流年（放大时）或大运起点（缩小时）。
- 已存在的事件用 `LongPressDraggable` 拖动改期；区间事件两端各一个把手，
  拖把手改 `startAge`/`endAge`。

## 7. 事件与大运/流年的关联，以及一条红线

**关联方式**：事件只存年龄区间（`TimelineAnchor`），显示时才解析到
大运/流年（`LifeSpan.decadeAt` / `flowYearAt`）。所以：

- 换算逻辑集中一处，改大运步数、改起运算法都不会让存量事件错位；
- 同一事件天然能同时回答「在哪一步大运」「在哪一年」；
- 区间事件可跨大运，不需要拆成多条。

**红线**：用户拖动/新增的事件**不得回流进推理引擎**。

这与案例库那条守则是同一条：`理论固定，推演结构化，AI负责解释`。
用户把「升职」拖到某一年，不能因此改变规则权重或格局判定，否则理论就被
使用者的记忆悄悄改写了。`test/case_guardrail_test.dart` 已经在守
`core/analysis`、`core/rules`、`core/engine`、`core/models` 不得 import
案例库；`core/timeline` 已于 P2 加入同一张禁止清单。

（时间线事件要不要作为**上下文**写进 AI 提示词，是另一个问题，需单独决定——
见第 9 节待确认事项。）

## 8. 建议的实施分期

| 期 | 内容 | 可独立验收 |
|---|---|---|
| P1 | `_decadeCount` 8→12；`LifeSpan` 换算 + 单元测试 | 是 |
| P2 | 只读时间线：大运色块 + 流年刻度 + 缩放/滚动 | 是 |
| P3 | `timeline_scanner` 自动推荐（精简路径）+ 渲染标记 | 是 |
| P4 | 拖放增改删、区间把手、强度、持久化 | 是 |
| P5 | 事件类型扩充（贵人/留学/买房/名气…）+ 敏感开关与免责 | 是 |

每期都能单独跑通、单独合并，不需要一次性做完。

## 9. 已确认的口径

| 项目 | 决定 |
|---|---|
| 120 岁口径 | **虚岁 0-120**（age 1 = 出生年，`公历年 = 出生年 + 虚岁 - 1`） |
| 事件持久化 | 挂在**命盘**（八字 + 性别），与案例库解耦 |
| 生子判据 | **男以官杀为子，女以食伤为子** |
| 重算策略 | 用户拖动过的推荐事件保留（`EventOrigin.userMoved`） |
| 时间线事件进 AI 提示词 | 暂不进，待时间线稳定后单独决定 |
| 「破财风险」敏感级别 | **`normal`，不默认关闭**。默认关闭的只有点名的四类：离婚、大病/手术、寿元、官司 |

## 10. P1 实施记录（已完成）

- `_decadeCount` 8 → **12**。实测最早起运为 1 岁，第 12 步即 111-120，
  任何命盘都能覆盖到虚岁 120。
- 新增 `lib/core/timeline/life_span.dart`：年龄/公历年/大运/流年 的唯一换算入口。
  painter、命中测试、拖放三处共用，避免「画的和点的差一年」这类难查的错位。
- `endAge` 是**闭区间**（11-20 共十年），故大运在连续轴上占 `[startAge, endAge+1)`。
- 两处原本硬编码 `decades.length == 8` 的断言改为断言**覆盖到 120**，
  不再依赖一个会变的常数。
- `kEngineVersion` → 5：整体命局的应期排期原本只排 8 步大运，现在排 12 步，
  确定性输出已改变，旧缓存必须失效。

### 副作用（可见）

排盘页的大运列表与 AI 提示词的「大运列表」都会从 8 步变为 12 步。
这是必要的：时间线要画满两甲子，就不能只算到 90 岁。

## 11. P2 实施记录（已完成）

只读时间线。三个文件，职责不重叠：

| 文件 | 职责 |
|---|---|
| `features/timeline/timeline_geometry.dart` | 纯像素↔虚岁映射：`pxPerYear`/`offset`、平移、缩放、LOD、标签间隔。不含任何 Flutter 类型，可直接单测 |
| `features/timeline/timeline_painter.dart` | `CustomPainter`：小运带 + 大运色块 + 流年刻度 + 年龄轴 + 今天标线。另含 `TimelineRows`（纵向布局常量），P4 的命中测试要读同一份 |
| `features/timeline/timeline_page.dart` | 手势、选中态、详情面板、图例 |

要点与实测：

- **色块着色**：按大运天干的五行取色（`kElementColors`），阳干 alpha 0.30、
  阴干 0.16。相邻两步常是同五行（甲运接乙运），只靠颜色分不开，用深浅分。
- **刻度间隔与标签间隔是两件事**。刻度一像素就够，标签要 44 像素。
  `tickEvery` 按 LOD 给（10/5/1），`axisLabelEvery` 另按 `pxPerYear`
  从 [1,2,5,10,20] 里挑第一个够宽的。手机全览（≈3.25 px/年）落在 20 年一标。
- **今天标线**用「公历年 + 年内已过比例」定位，不是立春分界，故年初年尾可能
  差几周。仅作视觉锚点，不参与任何推演——已在代码注释里写明。
- **`LayoutBuilder` 必须放在 `Card` 里面**。放外面时 geometry 的
  `viewportWidth` 比画布实际宽度多出一个 card margin，画出来的位置和点下去的
  位置差好几岁。这个 bug 是 `timeline_ui_test.dart` 用「按 `xForAge(60.5)`
  反算坐标去点」的写法抓到的——测试里若写死像素就抓不到。
- **惯性暂缺**：自管 offset 的代价（见 6.1 的更正）。桌面/网页补了滚轮平移与
  Ctrl+滚轮缩放，另有放大/缩小/全览三个按钮兜底可访问性。

测试：`timeline_geometry_test.dart` 17 个（映射互逆、平移夹紧、缩放定点、
LOD 不跳级、标签不重叠），`timeline_ui_test.dart` 6 个（默认全览、点击选中、
小运期标注、缩放按钮、无命盘不崩）。

## 12. 仍待确认

1. **时间线事件是否作为上下文进入 AI 提示词**（见第 7 节）。倾向暂不进：
   用户手动摆放的事件一旦进了提示词，就成了一条绕过守则的反馈回路——
   模型会照着用户已经相信的事情解释命盘。等 P4 的持久化跑稳后单独决定。
