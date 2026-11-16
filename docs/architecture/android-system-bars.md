# Android 系统栏底部避让

本文记录 Android（以及同形态的 iPhone Home indicator）底部系统栏避让为什么会被页面「吃掉」，以及全项目统一的修法。

## 问题

Android 15（API 35）起强制 edge-to-edge：应用窗口铺满整屏，系统栏浮在内容之上。`flutter.targetSdkVersion` 当前为 **36**，因此所有 Android 15+ 设备都处于该模式，系统栏不再由窗口自己缩让（`MainActivity` / `styles.xml` 没有任何 `fitsSystemWindows`、`WindowInsets` 配置，这一层没有可退的开关）。

Flutter 侧的避让机制是「环境 `MediaQuery.padding` + 滚动组件自己消费」的协作，有两处关键实现：

1. `Scaffold` 在 `_addIfNonNull` 里对 body 只做 `removeTopPadding`，**不会**移除底部 padding；`minInsets.bottom` 只在 body 的 **高度** 上扣除（`_ScaffoldLayout.performLayout` → `contentBottom`）。也就是说 body 被压在系统栏上方一块，但环境 `padding.bottom` 仍然存在。
2. `BoxScrollView.buildSlivers` **仅当 `padding == null`** 时才把环境 `padding` 转成自己的 `SliverPadding`：

   ```dart
   EdgeInsetsGeometry? effectivePadding = padding;
   if (padding == null) { /* 用 MediaQuery.padding 作为 SliverPadding */ }
   ```

   一旦页面写死 `padding:`，这份避让就整个消失。

两处叠加的结果：`Scaffold` 已经把 body 的高度扣掉了系统栏那一条，写死 `padding` 的滚动容器既不消费 padding、又在这块被压住的高度里铺内容 —— 滚动到底时最后一行落在系统栏下方（#379 的截图：开发者页面的「检查更新」按钮被三键导航条压住）。

## 修法

统一用 [`withSystemBottomInset`](../../lib/utils/system_insets.dart) 把系统底部 inset 加回显式 `padding` 的底边：

```dart
padding: withSystemBottomInset(context, const EdgeInsets.all(16)),
```

- 取 `MediaQuery.paddingOf(context).bottom` 而非 `viewPadding`：键盘弹起时 `padding` 归零，底部空间正好由 `Scaffold.resizeToAvoidBottomInset` 接管，不会多留空白。
- **不要**在 `Scaffold.body: SafeArea(...)` 包裹的滚动容器上使用：`SafeArea` 消费的是 `viewPadding`，键盘弹起时仍会产生底部空白；这一只应当在「不消费系统 inset」的场合使用。
- **不要**用在 `showModalBottomSheet` 内部的滚动容器上：底部弹层自身贴底，其 `MediaQuery.padding.bottom` 等于弹层下方的距离（底部弹层被压在屏幕底边时即系统栏高度），其 inset 同样由调用方的 `SafeArea` 负责，叠加会多出一整条。

## 当前覆盖范围

截至本次修复，`lib/pages`、`lib/widgets` 下写死 `padding:` 的 `ListView` / `SingleChildScrollView` / `CustomScrollView` / `GridView` 都已接入，共 57 处。三张主页（课表 / 校园 / 个人主页）走 `HomeDockInsets` 自行读取浮动 Dock 的避让距离，不在此列。

`Scaffold.bottomNavigationBar` 与 `persistentFooterButtons` 由 `Scaffold` 自己保证安全区，底部弹层由调用方的 `SafeArea` 保证 —— 两类都不需要本工具。

**新增页面时**：只要滚动容器写了显式 `padding`，就要用该工具包一层；漏掉不会编译报错，只会在真机（尤其 Android 15+ 三键导航）上表现为末行被系统栏压住。
