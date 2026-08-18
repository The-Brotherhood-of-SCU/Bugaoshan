# 不高山上 · HarmonyOS（ohos）平台壳工程

本目录是「不高山上」Flutter 应用的 HarmonyOS 原生壳工程，用 **DevEco Studio** 打开本目录即可。

## 本次变更：原生沉浸光感悬浮底栏（ArkTS 系统级材质）

底栏由 **ArkUI 原生组件**接管（AppGallery 风格），Flutter 侧只做配置下发与
系统级行为收口：

- `entry/src/main/ets/dock/DockBridge.ets`：MethodChannel `bugaoshan/immersive_dock`
  桥接。Dart→ArkTS 推送底栏配置（逐字段读出 ES Map 后 JSON 存入
  `AppStorage['dockConfigJson']`；**注意 StandardMessageCodec 的 Map 不能直接
  `JSON.stringify`**，会得到 `"{}"`）。**写入前与现有配置比对，相同则跳过**——
  点击标签时原生侧已本地更新过选中态，Dart 回推相同内容再写一次会触发二次
  刷新（光标动画被打断重启，表现为切换卡顿）。ArkTS→Dart 回传标签点击。
- `entry/src/main/ets/components/NativeImmersiveDock.ets`：原生悬浮底栏。
  `uiMaterial.ImmersiveMaterial` 系统级材质（强度 0~4、智能反色、按压点光源，
  API<23 降级普通毛玻璃）；**每个标签是独立 @Component + 自有 @StorageLink**，
  规避 @Builder 标量参数不刷新的坑；选中项有**滑动胶囊光标**（`.animation`
  260ms），点击本地即时更新选中态再回传 Dart，无延迟感。
  **胶囊悬浮的关键**：底部间距（margin bottom 28）必须加在**材质容器自身**
  （margin 在容器外侧），若加在容器内部的条带上，材质会把下方空隙包进去，
  视觉上变成贴底的长条而不是悬浮胶囊。
  **二级页面**（Dart 推送 `covered=true`）时**整体不渲染**（含胶囊）——
  曾尝试过二级页改渲染贴底光感条，实测会压住手势小白条破坏沉浸，已撤销；
  二级页底部交由系统手势条直接绘制在页面内容上。
- `entry/src/main/ets/pages/Index.ets`：`Stack(alignContent: Bottom)` 中
  `FlutterPage` 之上叠 `NativeImmersiveDock`，内容可延伸到底栏下方透出光影；
  顶部另叠一条 **状态栏沉浸光感条**（ULTRA_THIN ImmersiveMaterial，高度读
  window avoidArea 状态栏高度，无阴影无交互），让状态栏带与页面内容之间
  有材质过渡而非生硬拼接。
- `lib/pages/campus/ccyl/ccyl_page.dart`：第二课堂页底部四标签栏在 ohos 且
  开启原生底栏时**接管原生沉浸光感胶囊**（`overrideDock` 推送 活动搜索/
  我参与的活动/预约的活动/成绩单 四标签，系统级 ImmersiveMaterial 材质与
  首页完全一致；图标经 ArkTS 侧 DockIcon 映射为系统 SymbolGlyph），Flutter
  侧不再渲染底栏；非 ohos 或关闭原生底栏时回退 `ImmersiveDockBar` /
  系统 NavigationBar。**接管有两层位置限定**：
  1. 仅作为**二级路由页面**时接管（`ModalRoute.isFirst == false`）。若用户
     在自定义 Dock 栏把第二课堂加为首页标签（页面内嵌于首页 IndexedStack，
     不 dispose），本页改用**顶部 TabBar** 切换子标签，底部仍是首页胶囊——
     否则覆盖残留会让 ccyl 胶囊错误出现在所有页面上；
  2. 仅**路由 current** 时才允许接管（build 中判断 `ModalRoute.isCurrent`）：
     被三级页面（活动详情/绑定页）覆盖时本页不 dispose，provider 通知驱动
     的 rebuild 会重新执行 build——不加此判断，RouteAware 让出的胶囊会被
     rebuild 重新推送复活。三级页面压上时 `didPushNext` 让出、返回时
     `didPopNext` 手动恢复（路由返回不触发 build）。
- `entry/src/main/ets/entryability/EntryAbility.ets`：显式
  `setWindowSystemBarProperties` 把状态栏/导航条颜色固定为全透明
  （FlutterAbility 已 setWindowLayoutFullScreen 全屏绘制，状态栏沉浸
  本已生效，此处使其不依赖系统默认值）。
- **切换性能**：原生底栏模式下 `AuthScopedIndexedStack` 关闭切页滑动/淡入
  动画（`home_page.dart` 中 `enableAnimation && !nativeDockActive`）——
  两个重型页面同屏动画是切换掉帧主因，瞬时切换与 HarmonyOS 原生应用
  一致；曾尝试用 RepaintBoundary 隔离页面图层，实测反而增加合成开销，
  已撤销。
- `lib/services/immersive_dock_service.dart`：Dart 侧系统级收口——
  - 配置推送带**内容去重**（jsonEncode 比对，相同配置不走通道，消除切换卡顿）；
  - `routeObserver` 挂 `MaterialApp.navigatorObservers`，首页（RouteAware）被
    **二级页面覆盖时自动隐藏底栏**，返回自动恢复；
  - `dockVisible` 全局通知 + `context.immersiveDockInset` 扩展：app 层
    `MaterialApp.builder` 在底栏可见时向 MediaQuery.padding 注入 96 逻辑像素，
    滚动视图自动获得**底部限位**（滚到底时内容停在底栏上方；显式设置了
    padding 的滚动视图用 `+ EdgeInsets.only(bottom: context.immersiveDockInset)`
    叠加，见 campus_page / profile_page）；
  - **页面级覆盖**（`overrideDock`/`clearOverride`）：二级页面可推送自己的
    标签组接管原生胶囊（covered 被压为 false，材质参数沿用首页全局设置），
    点击事件改发 `onOverrideTap`；`dockVisible` 此时保持 false，避免 app 层
    与页面自身的底部限位重复注入。页面 dispose / 进入更深层路由前须
    `clearOverride` 恢复首页配置。
- `lib/pages/settings/set_immersive_page.dart`：设置入口（软件设置 → 样式 →
  沉浸光感），原生底栏开关 / 智能反色 / 按压光效 / 材质强度滑杆。
- 非 ohos 平台或关闭原生底栏时，回退到 Flutter 侧
  `lib/widgets/common/immersive_dock_bar.dart`（BackdropFilter 等效实现）。

## 上一轮变更：沉浸光感启动遮罩（ImmersiveLaunchOverlay）

- `entry/src/main/ets/components/ImmersiveLaunchOverlay.ets`：**新增**。启动遮罩层，使用
  `uiMaterial.ImmersiveMaterial`（`@kit.ArkUI`，沉浸光感材质：毛玻璃通透 + 材质流光 +
  按压点光源 + 智能反色），渐变底色 + 光斑衬托。运行设备 API < 23 时自动降级为
  `backgroundBlurStyle` 普通毛玻璃。
- `entry/src/main/ets/pages/Index.ets`：**修改**。改为 `Stack` 布局，`FlutterPage` 之上叠加
  沉浸光感启动遮罩，约 1.2 秒（预留引擎预热与首帧时间）后淡出并从组件树移除。
- `entry/src/main/ets/entryability/EntryAbility.ets`：保持模板逻辑不变；
  `FlutterAbility` 内部已调用 `setWindowLayoutFullScreen(true)` 实现沉浸式全屏窗口。
- `lib/widgets/common/immersive_dock_bar.dart`：**新增**。Flutter 侧沉浸光感悬浮
  底栏（圆角 32 + BackdropFilter 高斯模糊 + 通光渐变 + 高光描边 + 悬浮投影，
  明暗主题自适应）。`lib/pages/home_page.dart` 已接入：窄屏时的
  `bottomNavigationBar` 换成 `ImmersiveDockBar`，并设置 `extendBody: true`
  让页面内容滚到底栏下方透出光影。

> 由于应用业务 UI 全部由 Flutter 渲染，系统级沉浸光感只能作用于 ArkUI 原生层；
> Flutter 页面内部的玻璃质感用 `BackdropFilter` 等效实现（即上面的悬浮底栏）。

## 性能说明

滑动卡顿来自 **debug 构建**（JIT 解释执行）。日常使用请安装 **release 包**
（AOT 编译，体积也从 ~160MB 降到 ~34MB）：

```bash
flutter build hap --release
```

## 构建环境（已在本机配置好）

环境变量集中在 `../toolchain/env.sh`（已追加到 `~/.zshrc`）：

- flutter_ohos 工具链：`../toolchain/flutter_flutter`，分支 **oh-3.41.9-release**
  （Flutter 3.41.10-ohos / Dart 3.11.5）。注意：**不要**切到 oh-3.44.9-dev，该分支
  尖端框架与已发布的 ohos 预编译引擎不匹配（dart:ui 缺 displayCornerRadii）。
- HarmonyOS SDK：DevEco Studio 26.0 内置（API 26，HarmonyOS 26.0.0 Beta2）
- JDK：DevEco 内置 JBR；hvigor/ohpm/node：DevEco 内置
- 已配置 `~/.npmrc` 华为镜像源；git 全局配置 GitHub 加速镜像（ghfast.top）

## 构建步骤（重要：必须在纯 ASCII 路径下构建）

hvigor 不支持含中文/空格的项目路径，而本工作区路径含中文，因此构建需在 ASCII
目录进行（已备好 `/Users/huangjieqi/bugaoshan_build`）：

```bash
# 1. 同步源码到构建目录
rsync -a --exclude '.dart_tool' --exclude 'build' \
  <本工程目录>/ /Users/huangjieqi/bugaoshan_build/Bugaoshan/

# 2. 构建（产物在 ohos/entry/build/default/outputs/default/）
flutter pub get && flutter build hap --release   # 或 --debug
```

已验证：`flutter build hap --debug` 全链路通过，真机（SCA-AL00, HarmonyOS 7.0.0.100）
冷启动进入 Flutter 主界面正常。

## OpenHarmony 插件依赖（pubspec.yaml，本次补齐）

原源码 zip 的 pubspec **缺少全部 ohos 平台插件实现**，导致构建出的应用启动即崩溃
（`MissingPluginException: shared_preferences` 等）。pub.dev 官方包均未声明 ohos
实现，且 pub.dev 上的几个 `*_ohos` 独立包停留在 Dart 2 时代约束无法使用。现按
openharmony-sig 的 gitcode 移植仓库补齐，与原 hap 内嵌 har 清单完全对齐：

- 直接依赖（实现包，`implements` 机制）：`shared_preferences_ohos`、
  `url_launcher_ohos`、`image_picker_ohos`（gitcode openharmony-sig/flutter_packages）
- dependency_overrides（ohos 支持做在移植版主包内）：`path_provider`、
  `sqflite`（br_v2.4.2_ohos，与 app 约束同版本）、`share_plus`
  （br_share_plus-v12.0.1_ohos）、`package_info_plus`
  （br_package_info_plus-v9.0.0_ohos）、`device_info_plus`
  （br_device_info_plus-v12.3.0_ohos，仅 Android 分支调用，降级无影响）
- `flutter_secure_storage`：vendored 到 `third_party/flutter_secure_storage`（基于
  gitcode fluttertpc_flutter_secure_storage），放宽 SDK 约束到 Dart 3.x、
  platform_interface 升到 ^2.0.1、har 模块名统一为 `flutter_secure_storage`。
  **注意：该副本只声明 ohos 平台，构建 Android/iOS/桌面端前需移除此覆盖。**
- `file_picker` 降到 ^11.0.3：12.x 的 windows_file_picker 依赖 win32 ^6，与移植
  版插件链的 win32 ^5 冲突；app 仅用 11.0 已有的 `FilePicker.saveFile`（返回值
  为 `String?`，`lib/utils/calendar_export_utils.dart` 已相应改回 `String?`）。
- 版本冲突排查技巧：移植版接口包内 git 依赖的 **URL 必须逐字符一致**
  （openharmony-sig 与 openharmony-tpc 是同内容不同源，混用会被 pub 视为冲突）。

未接入 ohos 的插件：`file_picker`、`gal`、`open_filex`、`flutter_inappwebview`、
`window_manager`/`screen_retriever`/`system_theme`（桌面端）等。它们在 ohos 上调用
会抛 MissingPluginException；启动路径已验证不依赖它们，具体页面用到时需再评估。

### 签名（最后一步）

未签名 hap 无法安装。打开 DevEco Studio → File → Project Structure →
Signing Configs → 登录华为开发者账号并勾选 **Automatically generate signature**，
然后重新执行 `flutter build hap` 即可得到签名包。

## 已知坑位（本次踩过并解决）

1. **Dart 兼容补丁**：`lib/pages/settings/set_dock_page.dart` 使用了 Flutter 3.44 才有的
   `onReorderItem`，已改为等价的 `onReorder`（含 newIndex 语义修正）。换回 3.44+
   工具链时可还原。
2. **os_type 插件补丁**：其 ohos 模块未声明 `@ohos/flutter_ohos` 依赖，已通过
   `third_party/os_type` 本地副本 + pubspec `dependency_overrides` 固化修复。
3. **SDK 版本写法（DevEco 26 / API 26 SDK）**：`compileSdkVersion` 与 `targetSdkVersion`
   必须用新版点分格式 `"26.0.0"`（API 26 起不再带括号）；`compatibleSdkVersion` 用旧版
   映射格式 `"6.1.0(23)"`（沉浸光感要求 API 23+，且与原包 target 对齐）。缺
   `compileSdkVersion` 会导致 DevEco 同步报"值不正确"。
4. **构建副作用**：构建时 flutter 工具会向 `ohos/build-profile.json5` 和
   `ohos/oh-package.json5` 注入插件模块/override 路径，并生成 `oh_modules/`、
   lock 文件。迁移构建目录前需清理这些文件（或从本仓库恢复模板版本）。

## 配置基线（与原 hap 一致）

- bundleName：`com.scubrotherhood.bugaoshan`，versionName `2.3.0`，versionCode `20300`
- compileSdkVersion `26.0.0`，compatibleSdkVersion `6.1.0(23)`，targetSdkVersion `26.0.0`；
  沉浸光感在 API 23+ 设备生效，低版本设备不再支持（API 23 以下）
- 权限：`ohos.permission.INTERNET`；设备类型：phone
