# ADR-0009：课表导出为图片采用「离屏挂载 + RepaintBoundary 捕获」

- 状态：已接受并实施
- 决策日期：2026-10-09

## 背景

「导出课表」弹层原本只有复制 JSON、导出 .ics、导入系统日历三条路径。新增「导出为图片」要把**当前周课表完整渲染成 PNG**：从表头开始、覆盖第 1 节到最后一个节次、不受手机屏幕高度与当前滚动位置影响、不含页面壳（工具栏 / Dock / 底部导航）、并且继承用户当前的课表视觉设置与深浅色主题。

真正的难点只有四个，且都不在「画课表」上：

1. **完整布局**：现有 `CourseGrid` 的主体被包在 `Expanded → SingleChildScrollView` 里，天然只渲染可视区；要拿到完整图必须复用同一套布局代码却不能带滚动与 viewport 裁剪。
2. **资源就绪**：`BackgroundImageView` 用 300ms `AnimatedOpacity` 淡入，首帧未命中 ImageCache 时是不透明 0；Google Fonts 也可能尚未加载到引擎。此时截帧会得到「没有背景 / 字体回落」的图。
3. **离屏挂载**：把一棵树挂在屏幕外还要保证它真的完成 paint，是最容易踩坑的一步。
4. **主题继承**：导出图必须与 App 当前主题一致，不能强制浅色或深色。

## 决策

**在标准 Flutter Widget tree 内以「真实坐标挂载 + 不透明遮罩覆盖 + 预热先行 + 等一帧后捕获」的方式产出 PNG；渲染一次，输出与渲染解耦。**

1. **复用现有渲染组件，不写第二套绘制。** 从 `CourseGrid` 抽出 `CourseGridHeader`（表头二选一）与 `CourseGridBody`（参数化、无滚动、无 GetIt、无 Listenable），正常页面与导出视图共用；导出视图 `ScheduleExportView` = 不透明底色（`scaffoldBackgroundColor`）+ 可选 `BackgroundImageView` + `Column(min)[Header, Body]`。禁止新增 `CustomPainter` / `SchedulePainter` / `ExportCourseCard`。
2. **挂载方式**：模态加载路由内，`Stack(clipBehavior: Clip.none, alignment: topLeft)` 中把 `RepaintBoundary` 放在 `Positioned(left: 0, top: 0, width: kScheduleImageLogicalWidth)`（**只给宽度，高度无界**，由 `Column(mainAxisSize: min)` 自然撑高），随后用一个不透明的同尺寸覆盖层（同时是 loading UI）盖住它。**禁止** `Offstage`、`Opacity(0)`、`left: -99999`、以及手搓 `BuildOwner`/`PipelineOwner`/`RenderView` 根。
3. **资源就绪必须早于首次 build**：`GoogleFonts.pendingFonts()` 只等一次（3s 超时、失败仅告警）+ 有背景图时 `precacheImage(FileImage, context, onError:)`（文件不存在或 `onError` 触发则记为「无背景」），**全部完成后再 `setState(_ready = true)` 首次构建导出子树**；随后只等一帧 `WidgetsBinding.instance.endOfFrame`（8s 超时）即可捕获。
4. **样式来源 = live `AppConfigProvider`，不引入样式快照。** 导出视图与 `CourseGrid` 读取同一组设置；组件层不做「第二套配置入口」。
5. **数据来源 = 显式 `ScheduleExportData(config, courses, targetWeek)`**，渲染器与视图不得读 `CourseProvider`。主页取 `CoursePageController.visibleWeek`（用户当前浏览的那一周，不是系统当前周）；课表管理页导出非当前课表时取 `config.getCurrentWeek().clamp(1, totalWeeks)`（未开学 → 第 1 周，已结束 → 末周）。
6. **尺寸**：逻辑宽度固定 `kScheduleImageLogicalWidth = 420`（节次列 35 由共用常量保证比例），默认 `pixelRatio = 2.0`；仅按**总像素**上限（8MP）降级，不设单边纹理上限。
7. **输出**：渲染一次产出 `ScheduleImageArtifact(pngBytes, baseName, …)`，再弹出**恰好三项**的动作层（保存到系统相册 `gal` / 系统分享 `share_plus` + `share_utils.shareSingleFile` / 取消）。取消不是失败。顺序固定为「**先生成、后选择**」：加载页出现在生成阶段，生成失败时用户不会先做选择，两个输出动作只消费同一个 artifact。生成入口 `render` 与输出分发 `output` 都带默认实现、可注入，因此 flow 测试能在不触碰真实文件 IO 的前提下断言「只渲染一次 + 只分发一次」。

## 理由

1. **离屏挂载之所以不用 `Offstage`/`Opacity(0)`**：`RenderOffstage.paint` 在 offstage 时直接 `return`，`RenderOpacity.paint` 在 `alpha == 0` 时直接 `return` —— 两者都**不会绘制子树**，`RenderRepaintBoundary.toImage()` 的 `assert(!debugNeedsPaint)` 会失败（release 下则捕获到上一次的旧内容）。真实坐标挂载 + 不透明遮罩不存在这个问题：同一帧内按 children 顺序绘制，遮罩在后，用户看不到渲染树。
2. **`Stack` 的绘制顺序就是 children 顺序**（`RenderStack.paintStack → defaultPaint`），因此背景可以写成 `Positioned.fill` 放在 `Column` 之前；而尺寸只由**非 positioned** 子节点决定，所以 `Column` 必须放最后且是唯一非 positioned 子节点。
3. **预热必须先于首次 build**：`FileImage.obtainKey` 返回 `SynchronousFuture(this)`，缓存键只由 `path + scale` 决定、与 `ImageConfiguration` 无关，因此 `precacheImage` 之后 `BackgroundImageView.initState` 里的 `_resolveImageSize()` 会同步命中 → 首帧 `ready = true`、opacity 直接 1.0、不播淡入。反之（先挂载后预热）会先以 opacity 0 构建，解码完成后再把目标值从 0 改成 1 → 真播 300ms 淡入，只等一帧必然截到接近透明的背景。
4. **不引入样式快照（`CourseRenderStyle`）**：导出窗口由模态路由阻塞输入，且仓库内没有任何非用户来源会写这组视觉设置（唯一的异步写是导入流程里的 `showWeekend`，它需要用户停留在导入 Sheet 内），因此 live 读与快照取值等价；而快照是**第二份字段清单**，将来新增视觉设置时忘记同步会让导出图与实况静默不一致。ADR-0003 已规定显示偏好归 `AppConfigProvider`，直接复用它的读取路径最省。
5. **release 下没有「新鲜度判据」**：`debugNeedsPaint` 是只在 `assert` 内赋值的 `late bool`，release 读取会抛 `LateInitializationError`（`rendering/object.dart`）；`RenderRepaintBoundary.toImage` 自身的前置条件也只有这句 assert。因此新鲜度只能靠**结构顺序**保证：所有异步状态变化都在最后一次 `endOfFrame` 之前完成，之后到 `toImage` 之间不得再有 `setState`。`boundary.layer == null` 仅作为「至少合成过一次」的非空守卫，不代表最新一帧已 paint。
6. **高度不再由公式决定**：`boundary.size` 就是真实布局结果，生产代码里不存在 `40*textScale + rowHeight*sections` 这类第二份高度知识；公式只作为测试里的期望值。
7. **祖先裁剪不影响产物**：`OffsetLayer._createSceneForImage` 只从本层子树构建 scene，因此即使渲染树超出 viewport、或被祖先 ClipRectLayer 裁剪，捕获到的仍是完整边界内容（仍需真机 PoC 确认，见「后果」）。

## 已评估但未采用

| 方案 | 否决理由 |
|---|---|
| `Offstage` 挂载 | `RenderOffstage.paint` 在 offstage 时直接返回，子树不 paint，`toImage` 不可用 |
| `Opacity(0)` 隐藏 | `RenderOpacity.paint` 在 `alpha == 0` 时直接返回，同上 |
| `Positioned(left: -99999)` 移出屏幕 | 依赖「移出 paint bounds 仍完整绘制」的未验证假设，且容易被后人误改 |
| 手搓 `BuildOwner`/`PipelineOwner`/`RenderView` 根 | 丢失 `Theme`/`Localizations`/`MediaQuery` 等 InheritedWidget，SDK 升级风险高 |
| `CourseRenderStyle` 样式快照 | 前提（导出期间配置不变）已成立，快照反而引入第二份字段清单与完整性腐化风险 |
| 8192 单边像素上限 | 逻辑宽度固定 420 时，它与总像素上限在我们的形状下近乎等价；实测 UI 可达最坏配置仅 6.18MP |
| release 新鲜度判据 | 不存在等价检查（`debugNeedsPaint` 在 release 不可用），只能靠结构顺序 + 真机 PoC |
| production `debugRenderCount` | 用可注入的 `ScheduleImageRender` / `ScheduleImageOutputDispatcher` 测试缝替代，避免在生产类里留调试全局量 |
| flow 测试驱动真实文件 IO | `shareScheduleImage` 会真的写临时文件，在 widget test 的 FakeAsync 下需要 `await flowFuture` 才能推进；改为注入 `output` 假实现后，flow 测试完全确定性，真实 IO 路径由独立用例（`tester.runAsync`）覆盖 |

## 后果

正面影响：

- 导出图与实况课表同源（同一套 Header/Body/CourseCard/BackgroundImageView + 同一份 AppConfig），不存在「导出专用样式」漂移。
- 渲染与输出解耦：`ScheduleImageArtifact` 只生成一次，两个输出动作只消费它；PNG 不会被重复渲染。
- 不新增插件、不改 `pubspec.yaml`、不改 Android/iOS 原生配置（gal 所需的 `WRITE_EXTERNAL_STORAGE (maxSdkVersion=29)` 与 `NSPhotoLibrary*UsageDescription` 仓库已有）。
- 导出路径完全独立于共享的 `CalendarExportUtils.showActionSheet`（只新增通用条目 API），考表页与校历页 0 diff。

代价与约束：

- **必须真机 PoC 两项**：① 超长课表越出屏幕后 `toImage` 是否完整捕获（失败则停止并重新归因，不预设 fallback）；② 带背景图导出是否「不缺失、不半透明、crop 正确、深浅色跟随」。
- **release 无自检**：新鲜度只能靠固定顺序保证，debug 下才有 `assert(!debugNeedsPaint)` 绊线；任何在「最后一次 `endOfFrame`」与「`toImage`」之间插入 `setState` 的改动都会破坏该不变量。
- **8MP 上限不可达**：按当前 UI 上限（每段节数 ≤10，即 `sectionsPerDay ≤ 30`、`rowHeight ≤ 120`、textScale ≤ 2）最坏为 840×7360 ≈ 6.18MP，因此该上限只是内存保险，不应被描述成设备硬限制。
- **图片输出仅 Android/iOS**：桌面端不出现「导出为图片」，也不提供「保存到文件」替代路径；`isScheduleImageExportSupported` 需保持 `!kIsWeb && (Platform.isAndroid || Platform.isIOS)`。
- 若某设备因纹理上限导致 `toImage` 失败，当前实现走统一失败提示（用户可重试），不做按设备探测纹理上限的自动降级。

## 相关实现

- 渲染树：`lib/pages/course/export/schedule_export_view.dart`、`lib/pages/course/widgets/course_grid_body.dart`
- 渲染层（数据模型 / DPR 策略 / 离屏挂载与 RepaintBoundary 捕获）：`lib/pages/course/export/schedule_image_renderer.dart`
- 输出层（三项动作 Sheet / 相册 / 分享 / 完整 flow）：`lib/pages/course/export/schedule_image_export.dart`（以 barrel 方式 re-export 渲染层，调用方 import 入口不变）
- 接线：`lib/utils/export_schedule_utils.dart`、`lib/utils/calendar_export_utils.dart`、`lib/pages/course/main/course_page.dart`
- 测试：`test/course_grid_body_test.dart`、`test/schedule_export_view_test.dart`、`test/schedule_image_export_test.dart`、`test/export_schedule_wiring_test.dart`、`test/export_schedule_provider_snapshot_test.dart`
