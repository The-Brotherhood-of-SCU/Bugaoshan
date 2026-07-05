# 课表显示设置域归属设计决策

## 概述

统一「课程表样式」（全局）与「课表设置」（课表域）中四个显示开关的归属，
消除域混淆与设置项冗余。

## 背景

### 当前架构

```
软件设置 (AppConfigProvider / SharedPreferences)
└── 课程表样式 (SetCourseStylePage)          ← 全局，不随课表切换
    ├── 颜色深度 / 字号 / 行高
    ├── 显示课表网格 / 背景图片
    └── 显示教师 / 显示教室 / 显示周末 / 显示非本周课程  ❓ 新加，读写 ScheduleConfig

课表设置 (ScheduleConfig / SQLite)
└── 课表设置 (CourseScheduleSetting)         ← 课表域，随课表切换
    ├── 学期配置 / 节次时间 / 时段
    └── 显示教师 / 显示教室 / 显示周末 / 显示非本周课程  ✅ 原生
```

### 问题

1. **域混淆**：`SetCourseStylePage` 在软件设置（全局域）下，但其新增的四个开关读写 `courseProvider.scheduleConfig.value`（课表域）。用户在全局页面修改了设置，切换课表后这些设置会丢失，产生不一致。

2. **设置冗余**：四个显示开关同时在两个页面出现，用户和管理者都难以判断哪个是生效的。

3. **预览矛盾**：预览区域使用 `_kDemoCourses`（静态 demo 数据），而下面开关修改的是**当前课表**的 `ScheduleConfig`——开关与预览之间没有直接的数据关联。

## 备选方案

### 方案 A：将四个显示设置提升为全局设置（推荐）

将 `showTeacherName` / `showLocation` / `showWeekend` / `showNonCurrentWeekCourses` 从 `ScheduleConfig` 迁移到 `AppConfigProvider`，使其成为全局设置。

**改动范围：**

| 文件                                            | 改动                                                                   |
| ----------------------------------------------- | ---------------------------------------------------------------------- |
| `lib/models/course.dart` — `ScheduleConfig`     | 移除 4 个字段及 `copyWith`、序列化                                     |
| `lib/providers/app_config_provider.dart`        | 新增 4 个 `ValueNotifier<bool>`，加载/保存到 SharedPreferences         |
| `lib/widgets/course/course_card.dart`           | 从 `config.showLocation` → `appConfig.showLocation`                    |
| `lib/widgets/course/course_grid.dart`           | 从 `config.showWeekend` → `appConfig.showWeekend`                      |
| `lib/widgets/course/grid_header.dart`           | 从 `config.showWeekend` → `appConfig.showWeekend`                      |
| `lib/widgets/course/grid_logic.dart`            | 移除参数 `showNonCurrentWeekCourses`，由函数内部读 `AppConfigProvider` |
| `lib/pages/course/course_schedule_setting.dart` | 移除四个开关                                                           |
| `lib/pages/course/import_schedule_page.dart`    | `config.showWeekend` → `appConfig.showWeekend`                         |
| `lib/pages/settings/set_course_style_page.dart` | 开关改为读 `appConfig`，移除 `CourseProvider` 依赖                     |

**优点：**
- ✅ 语义清晰：显示偏好是全局设置，不随课表切换
- ✅ 消除冗余：只在一个地方出现
- ✅ 预览准确：所有预览项都是全局设置，demo 数据与设置域一致
- ✅ 用户预期一致：在「课程表样式」里改的，所有课表都生效

**缺点：**
- ❌ 破坏性变更：`ScheduleConfig` 序列化格式变更（字段移除），需处理存量数据向后兼容
- ❌ 迁移成本：涉及 7+ 个文件改动
- ❌ 不再支持「不同课表不同显示设置」（但此需求极弱）

### 方案 B：撤销改动，回归课表域

删除 `SetCourseStylePage` 中新增的四个开关，保留仅在 `CourseScheduleSetting` 中。

**改动范围：**
- `set_course_style_page.dart`：移除四个开关、`CourseProvider` 依赖、`scheduleConfig` 监听

**优点：**
- ✅ 零风险，纯删除
- ✅ 保持原架构纯洁

**缺点：**
- ❌ 用户无法在预览时直接调整显示设置
- ❌ 四种显示设置依然与字体/颜色/行高分离在两个页面，用户需要来回跳转

### 方案 C：合并两页

将 `SetCourseStylePage` 的样式预览合并到 `CourseScheduleSetting` 中，在课表设置页内提供预览。

**优点：**
- ✅ 预览+设置同页，所见即所得
- ✅ 保持课表域一致

**缺点：**
- ❌ 语义降级：颜色深度、字号、行高、背景图等应全局生效，放在课表设置页误导用户以为它们是课表域
- ❌ 从软件设置进入的路径消失，用户需要先进入课表才能调整样式
- ❌ 较大重构

### 方案 D：两域共存，添加文档说明

保留当前实现，在 UI 上添加文字提示区分设置域。

**优点：**
- ✅ 零代码改动

**缺点：**
- ❌ 冗余永久化，维护负担
- ❌ 用户困惑无法根本解决

## 推荐方案

**方案 A** — 将四个显示设置提升为全局设置。

### 理由

1. 四个显示设置（显示教师、教室、周末、非本周课程）本质上是**视觉偏好**，与字号、行高、颜色深度同类。没有强理由要求不同课表使用不同的显示偏好。

2. 本项目已有 `AppConfigProvider` 存储同类设置（`courseCardFontSize`、`showCourseGrid`、`courseRowHeight`），扩展它是最自然的做法。

3. 唯一合理的「按课表隐藏周末」场景，可以通过课表名称或备注来识别，不需要将设置绑定到 `ScheduleConfig`。

### 迁移计划

#### Step 1：AppConfigProvider 新增字段

```dart
// lib/providers/app_config_provider.dart
final ValueNotifier<bool> showTeacherName = ValueNotifier<bool>(true);
final ValueNotifier<bool> showLocation = ValueNotifier<bool>(true);
final ValueNotifier<bool> showWeekend = ValueNotifier<bool>(false);
final ValueNotifier<bool> showNonCurrentWeekCourses = ValueNotifier<bool>(true);
```

在 SharedPreferences 中新增对应持久化 key，`_loadPreferences` 中加载。

#### Step 2：ScheduleConfig 移除字段

- 从 `ScheduleConfig` 类、构造、`copyWith`、`fromJson`、`toJson` 中移除四个字段
- 不移除也可兼容：`fromJson` 读到旧数据时忽略即可（对端不再写入），但为了清晰建议移除

#### Step 3：消费方迁移

- `course_card.dart`：`config.showLocation` → `appConfig.showLocation`，`config.showTeacherName` → `appConfig.showTeacherName`
- `course_grid.dart`：`config.showWeekend` → `appConfig.showWeekend`
- `grid_header.dart`：`config.showWeekend` → `appConfig.showWeekend`
- `grid_logic.dart`：`showNonCurrentWeekCourses` 改为从 `getIt<AppConfigProvider>()` 读取，函数签名简化
- `import_schedule_page.dart`：`config.showWeekend` → `appConfig.showWeekend`

#### Step 4：UI 源清理

- `course_schedule_setting.dart`：移除四个开关及其 State 字段和 `_save` 中的对应参数
- `set_course_style_page.dart`：开关改为读 `appConfig`，移除 `CourseProvider` 依赖和 `scheduleConfig` 监听

#### Step 5：重置按钮

`set_course_style_page.dart` 的「恢复默认」按钮补充四个新字段的复位。

### 向后兼容

- SharedPreferences 无默认值问题：`_loadPreferences` 使用了 `??` 兜底
- ScheduleConfig 存量数据库 JSON 仍保留旧字段，`fromJson` 忽略多余字段即可——`json['showTeacherName']` 虽然会读到但不再使用，无影响
- 建议在迁移后运行一次 `dart run build_runner build` 确保无编译错误

## 状态

提议中 — 待实施。

## 决策时间线

| 日期       | 决策                              |
| ---------- | --------------------------------- |
| 2026-07-05 | 方案 A 选定为推荐方案，本文档创建 |
