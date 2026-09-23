# 通知页上游与鸿蒙显示差异

日期：2026-09-16。本文记录青春川大大小/位置、通知页主题和 WebView 生命周期的排查过程。
最新反馈：用户确认原生主题修复“正常运行了”，已显示网页切换主题时刷新、卡住及 Load Failed
的问题记为通过；随后用户确认第四阶段其余部分均无问题，已全部勾选，见 [第四阶段收尾清单](../phases/phase4.md)。
下文早期“待验收”描述保留排查时的状态；当前状态以文末完成记录为准。代理未执行构建或测试。

## 是否跟上上游

只读查询上游 `refs/heads/main` 得到 `e5c38070e154ab1a62b701534055e03ab9c8861f`，
与本地 HEAD 及源码补丁基线一致。根源码无未提交修改。因此相对本次查询到的上游 main，
通知页没有落后提交，也没有遗漏美化脚本同步。

- 三个入口共用 [WebViewNoticePage](../../../lib/widgets/webview/webview_notice_page.dart)。
- 美化脚本沿用根 `assets/js/jwc_notice_beautify.js`、`party_notice_beautify.js`、`tuanwei_notice_beautify.js`。
- [OH WebView 覆盖文件](../../flutter/overrides/lib/widgets/webview/download_webview.dart)（原 `0004`）启用 OH WebView，增加下载组件并适配 CPF 下载回调；
  没有修改三份 JS、美化样式、视口或主题设置。
- OH 使用 CPF `flutter_inappwebview` 主包 6.1.5 / OH 实现 1.1.3，锁定提交
  `528fa913763148719cde7dae2dc22dc33f15da36`。以下插件结论以该提交为准，不能外推到所有鸿蒙 WebView。

## 青春川大大小与位置

已确认的鸿蒙适配缺口：上游通知组件设置 `useWideViewPort: false`。插件平台接口明确将此参数
标为 Android 支持，其语义是把网页布局宽度设为 WebView 控件的 CSS 像素宽度。
Android 原生实现调用 `setUseWideViewPort`；当前锁定的 OH 原生 Settings 和 Web 组件没有解析或使用这个参数。
因此把相同 Dart 设置传给 OH，并不能得到 Android 的视口宽度行为。

青春川大脚本将 `body`、`.web` 限制到最大 `640px` 并居中，重置 `.innerbox` 等容器宽度，
但没有设置 `meta[name=viewport]`。最大宽度只约束内容盒子，不会把浏览器的布局视口变为手机宽度。
OH 插件同时默认开启 `loadWithOverviewMode`，映射到 ArkWeb 的 `overviewModeAccess`。
若网站实际采用较宽的布局视口，居中和缩放仍按该视口计算，就可能出现内容偏小、留白或位置不合适。

这解释了“代码与上游一致，但鸿蒙显示不一致”的具体路径。尚未取得设备上的视口宽度、缩放值或
计算后样式，不能据此把每一个元素的偏移都归因于视口，也不能认定网站 DOM 已变化。
本次只读请求团委列表页返回 HTTP 202 的脚本校验页面，未取得真实通知 HTML/CSS，
所以没有确认当前网站是否另有未被上游脚本覆盖的固定宽度、定位或内联样式。

用户进一步指出另外两个通知正常。随后只读获取教务处和学工部的当前列表页，均返回 HTTP 200，
原始 HTML 已各自包含移动端视口声明：

- 教务处：`<meta name="viewport" content="width=device-width, initial-scale=1.0">`。
- 学工部：`<meta content="width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0,user-scalable=0" name="viewport">`。

因此这两个列表页可以通过网页自身的声明按设备宽度布局，不依赖 Android 专用的
`useWideViewPort: false` 参数。这为它们在 OH 正常显示提供了直接的源码依据。
上述观察仅覆盖当前列表页；青春川大真实 HTML 仍未取得，不能宣称其网站一定缺少 viewport。
三个通知共用 WebView 设置，参数未实现只是已确认的适配缺口，尚不足以单独证明青春川大异常的根因；
还需区分它实际加载文档的视口声明与网站容器样式是否被完整覆盖。

处理方向：在 OH 通知页适配中显式设置移动端视口（`width=device-width, initial-scale=1`），
结合明确的概览缩放设置处理布局；按用户最新要求关闭网页手势缩放。再根据真机仍有问题的具体元素补充容器样式，
不按某台手机写死宽高或偏移量。这些更改现在保存为 OH 完整 Dart 覆盖文件，只在构建副本应用。

## 青春川大移动端适配实现

用户确认目标为 `https://tuanwei.scu.edu.cn/index/gg.htm`，网站没有移动端适配。
实现现保存为 [青春川大布局文件](../../flutter/overrides/lib/widgets/webview/tuanwei_mobile_layout.dart)，
原 `0013` 及后续修改已合成为最终文件，登记在源码覆盖清单。
用户随后反馈退出重进偶尔出现原网页；本次更新遮罩与加载时序，更新后的效果待用户验收。

采用现有 WebView 加站点专用布局适配，继续使用上游通知美化、附件、图片和导航逻辑。
首先完成视口和已知容器的修复，再根据真机仍异常的元素调整样式；不预设所有错位均由同一因素引起。

### 1. 只匹配青春川大通知内容

同时检查页面域名为 `tuanwei.scu.edu.cn`，并识别通知列表或正文的 DOM 结构。
适配覆盖列表分页及站内通知正文；外部链接、校验页面和未识别结构不套用通知布局。
教务处、学工部继续使用各自布局规则。

### 2. 明确视口和容器的布局宽度

创建或更新 viewport 为 `width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=1, user-scalable=no`。
青春川大 WebView 显式设置 `supportZoom: false`、`builtInZoomControls: false`，关闭网页手势缩放，
并设置 `loadWithOverviewMode: false`，让正文按移动端宽度排版。根元素设置 `touch-action: pan-x pan-y`，
保留页面滚动与表格横向滚动，不注册阻断全部触摸事件的处理器。图片点击继续走上游的独立预览入口。

以现有脚本识别的 `#bg`、`#bg2`、`.web`、`.innerbox` 为起点，定向消除桌面固定宽度、
最小宽度、浮动和造成偏移的容器样式，使用 `box-sizing: border-box`。
主内容宽度随可用空间变化；大屏继续采用上游最大阅读宽度居中。手机内边距用统一样式表达，
不按设备型号或截图坐标写死位置，不批量重置全部后代元素的定位。

### 3. 按内容重排列表与正文

- 列表继续使用上游日期块加标题布局，标题允许多行，条目高度由内容撑开，处理长标题的溢出。
- 分页控件允许换行，窄屏不强行挤在一行。
- 正文图片保持比例并限制在内容宽度内；长链接可换行；宽表格采用局部横向滚动，避免撑宽整页。
- 用真实文档结构确认需要覆盖的规则；仅隐藏已识别的网站导航、侧栏等外围元素，不通过裁掉溢出内容掩盖宽度问题。

### 4. 接入现有注入流程

实际显示的仍是学校原网页：Flutter 提供外层导航和加载/失败界面，CPF WebView 承载网页，
上游 JS 隐藏站点外围导航、重排通知列表及正文并连接附件/图片回调，OH JS 增加视口与布局规则。
网页内容和原始链接继续来自学校网站，通知没有被另行抓取后重写成 Flutter 列表。

退出重进出现原网页的源码原因包括：初版首帧 `_realLoading` 为 false；上游遮罩透明度为 0.99；
初版在未识别通知结构、脚本错误或完成回调超时时仍会在 finally 中结束遮罩。
此外，锁定的 OH 插件 `InAppWebView.ets:1823` 起允许首次内容绘制或进度达到 100% 时提前发送
`onLoadStop`，并按 URL 去重，不能据此保证通知 DOM 已完整解析。

现由构建副本中的 `TuanweiNoticeLoader` 管理青春川大的独立加载状态：

1. 控制器创建前就进入加载态；首帧使用铺满 WebView 的不透明遮罩，背景色强制 alpha 255，
   不使用 0.99 透明度或淡出动画。遮罩阻挡网页交互和背后语义内容，附件按钮在此期间隐藏。
2. `onLoadStop` 到达后核对当前 URL，并等待本地美化脚本。若网页仍处于 `document.readyState === 'loading'`
   或尚未发现通知结构，最多等待 12 秒，每 250 毫秒重试；单次 JS 调用最多等待 3 秒。
   这些未匹配的尝试会在执行上游美化前返回，不重复绑定图片或下载事件。
3. 识别到通知后，设置视口、执行上游美化和 OH 布局规则；`0016` 进一步等待资源、字体和布局
   稳定，再经过双 `requestAnimationFrame` 记录当前加载序号并发送 `DOMReady`。只有本次完成信号才能显示网页。
4. `0016` 将等待桥接回调的上限调整为 12 秒；未收到时读取当前文档的完成标记、布局样式和内容节点作为兜底。
   只有这项确认成功才能显示，超时本身不代表美化成功。整个导航另有 30 秒超时。
5. 未识别内容、网络失败、脚本错误或超时会显示 Flutter 的“加载失败”，保留“重试”和
   “在浏览器中打开”操作；不会自动把未适配的原网页当作结果展示。重试重新加载当前页和本地脚本。

新导航使旧任务失效；同一次导航的重复完成事件不启动并行美化；销毁页面会释放等待和定时器。
视口和补充样式仍使用固定标识，新增逻辑不重建整套通知 DOM。
教务处和学工部继续使用各自的上游美化脚本；`0016` 将它们的加载与显示时序接入共用加载器。

### 5. 保存位置与验收

当时新增的 `0013-tuanwei-mobile-layout.patch` 现已迁为完整 Dart 文件，
通过补丁在构建副本的 `lib/widgets/webview/` 增加 `tuanwei_mobile_layout.dart`（JS/CSS 布局）
和 `tuanwei_notice_loader.dart`（加载状态与遮罩），接入通知组件。
现有补丁工具只接受 `lib/` 下的 Dart 文件，因此不直接修改根 `assets/js/`，也不扩大脚本允许的修改范围。
原始站点美化脚本继续从上游资源读取，辅助文件只保存本次布局增量。

由用户查看手机竖屏/横屏、长标题、分页、正文图片和宽表格、返回后布局及附件操作，
并确认双指或双击不能缩放通知网页、普通纵向滚动和表格横向滚动正常。
本次重点是反复退出重进、缓存命中、加载期间返回、慢网和断网后重试；美化完成前不应露出原网页，
失败时应显示可重试的提示，不能一直转圈。以上为待用户验证的目标，代理未执行构建或测试。
验收目标是字体和点击区域清晰、内容不偏移或被截断，宽表格只在局部滚动，已有下载导航可用。
三个通知页的深色模式按下文的原生 AUTO 方案处理，复用上游配色，不在青春川大布局规则内另写一套颜色。

## 三个通知页等布局稳定后展示

[布局就绪实现](../../flutter/overrides/lib/widgets/webview/notice_layout_ready.dart)（原 `0016`）处理两个显示间隙：
教务处和学工部原先在脚本读取前没有遮罩，并使用 0.99 透明度及淡出；青春川大虽然已有首帧遮罩，
但两个动画帧并不能保证稍后到达的字体、图片和网站样式不会再次改变布局。

现在三个通知页共用 `NoticeLayoutLoader` 的不透明遮罩和失败重试界面，首帧即进入准备状态。
在三个指定域名的主文档开始阶段，通过 `initialUserScripts` 注入临时的根元素透明规则；
该规则保留网页的尺寸计算及脚本执行，在原生导航先于 Flutter 遮罩更新时隐藏原始内容。
OH 插件会在进度事件重放文档开始脚本，因此使用文档级标记保证只安装一次，避免完成后又被隐藏。

加载流程按以下条件展示：

1. 等待本地脚本、核对当前 URL、确认 DOM 解析完成并出现本站通知结构；随后执行上游美化。
   青春川大另执行原有移动端视口与布局规则；教务处继续追加搜索框主题规则。
2. 等待 `document.readyState === 'complete'` 和字体加载结束；资源成功或失败均可结束文档加载，
   不等待未来因滚动才触发的懒加载请求。通过 DOM/尺寸观察和视口、正文宽高、滚动高度采样，
   确认至少三个连续动画帧且 250 毫秒没有观察到布局变化。
3. 撤掉网页内的隐藏规则，继续保留 Flutter 遮罩两个动画帧，再发送带本次加载序号的完成信号。
   Dart 确认后直接撤掉不透明遮罩，没有半透明过渡或提前结束加载的兜底。
4. 布局观察最多运行 11 秒，Dart 等待完成信号最多 12 秒，整次导航仍受 30 秒上限约束。
   未确认完成就显示失败/重试；超时不表示布局成功。准备观察结束会清理观察器和定时器。

同一文档中的美化具有一次性标记，避免历史缓存恢复或重复加载回调叠加搜索框及事件监听。
导航序号继续隔离旧完成信号。普通业务确认、附件下载和青春川大禁用缩放沿用既有补丁；主题同步见下文。
加载器准备失败的日志来源改为 `NoticeLayout`。本次仅完成代码，实际像素呈现仍需真机确认；
布局稳定判断覆盖展示前的窗口，不保证以后网站主动更新或用户滚动触发的内容不会重排。

## 三个通知页深色模式

三份上游美化脚本都已有 `@media (prefers-color-scheme: dark)`：教务处约第 232 行、
学工部约第 238 行、团委约第 242 行。因此不是缺少上游深色 CSS。

当前锁定插件的 Dart 设置默认 `forceDark = ForceDark.OFF`；OH 原生
`InAppWebViewSettings.ets` 默认 `darkMode = WebDarkMode.Off`，并将传入的 OFF 映射到 Off。
`WebNodeController.ets` 又将该值直接传给 ArkWeb `.darkMode(...)`。
上游通知组件仅设置 JavaScript 和 `useWideViewPort`，没有根据 `Theme.of(context).brightness`
传递深浅主题，也没有在主题变化时更新 WebView 设置；Flutter 的深色加载遮罩不会自动改变网页主题。

适配前已确认的是主题没有接通、OH 网页深色模式被配置为关闭。未在设备执行 `matchMedia`，所以未记录
设备的媒体查询返回值。原配置与用户看到三个网页都保持浅色的现象吻合。
上游共享组件本身也没有显式同步应用主题；OH 默认关闭深色使这一遗漏在鸿蒙端直接暴露。

当前由 [通知页覆盖文件](../../flutter/overrides/lib/widgets/webview/webview_notice_page.dart)（原 `0018` 的最终实现）采用鸿蒙原生主题切换：
三个通知页设为 `ForceDark.AUTO`，插件映射为 `WebDarkMode.Auto`，直接绑定到 ArkUI 的
`Web(...).darkMode(...)`。应用当前使用 `ThemeMode.system`，网页由 ArkWeb 随系统变化更新
深浅色偏好，现有 `@media (prefers-color-scheme: dark)` 自动选择配色。
`forceDarkAccess` 显式为 false，不启用算法强制染色。范围仍限定为三个通知页；
志愿四川与验证码窗口沿用原主题处理。

上一版 `0018-notice-css-theme.patch` 已删除，构建清单替换为原生主题补丁：
不再生成 `notice_css_theme.dart`，不转换上游 CSS，也不由 Flutter 设置 HTML 主题属性。
保留现有两套 CSS，一次随文档美化注入；系统切换时交由原生 WebView 重新计算配色。
这里不使用 `setSettings` 反复传入整份插件配置，也不调用 reload、重新创建 WebView 或美化脚本。

教务处搜索框在上游创建时只检查一次 `matchMedia`，因此继续保留 `0015` 的补充样式：
识别列表前的搜索输入框，以专用属性定位，使用深浅媒体查询及 `!important` 覆盖旧内联颜色。
背景、文字、边框和输入控件 `color-scheme` 随原生偏好一起切换；搜索业务逻辑沿用上游。

首次导航和翻页继续走 `0016` 的布局遮罩，等美化及布局稳定后显示。
单纯主题变化不重启加载器、不执行通知页主题 JS 探测，不主动重置当前分页、输入或滚动位置。
手动刷新和失败重试仍保留。原生 AUTO 跟随的是系统主题；若以后应用增加独立于系统的主题设置，
需要另行同步原生模式，不能假定它自动跟随 Flutter 的自定义 ThemeMode。

本次仅完成代码，未执行构建或测试。原生切换后能否完全消除设备上的卡住仍待用户验证。

## 主题切换时仅 WebView 内容卡住

用户确认 Flutter 工具栏仍可操作，卡住局限在 WebView 内容。源码发现一个明确的生命周期缺陷：

- 原 `DownloadWebView` 是 StatelessWidget，每次页面的主题、加载状态变化都会新建 `InAppWebView`。
- 锁定的 CPF 主包把 `platform` 对象保存在 Widget 上；其 State 的 build/dispose 直接使用当前
  `widget.platform`，没有迁移原平台对象的控制器。
- OH 实现把控制器保存在平台对象中，仅在原生视图创建回调里初始化。Flutter OH 的 `OhosView`
  在 viewType 不变时保留原生视图 ID。因此重新创建插件 Widget 可能留下“原生视图仍在，
  新平台对象却没有对应控制器”的状态，不能把 Flutter 重建直接等同于原生视图被销毁重建。
- 通知组件还主动调用控制器 dispose，而插件本身也负责释放控制器，所有权重复。

`0015` 将共用组件改为 StatefulWidget，在 initState 中只创建一次底层 `InAppWebView`，
页面存续期间持续返回同一个 Widget。事件闭包读取最新的 `widget.on...`，避免页面重建后
回调停留在旧状态；关闭页面时由插件唯一释放控制器。该修正覆盖通知页、志愿四川及验证码窗口。
青春川大遮罩和布局加载逻辑继续沿用 `0013`。

用户真机反馈：上述生命周期修改后仍会卡住；随后 `0017` 增加主题变化后刷新当前文档，
用户又确认已显示的网页切换后出现 Load Failed。这一提示来自布局加载器的通用失败界面，
既可能表示主文档错误，也可能表示 JS 或布局确认超时，不能直接认定网络失败。
刷新复用同一个原生 WebView；若脚本或动画帧仍不响应，重新加载仍可能进入等待失败。
目前没有足够证据确定原生渲染或合成层的具体根因。

按用户最新要求，`0018` 移除 `0017` 的主题刷新回调和调度状态，并替换上一版属性方案，
恢复 ArkWeb 原生 AUTO。`0017` 仍作为补丁顺序中的前置上下文保留，最终代码不再因主题变化
调用加载器 retry。工具栏刷新和失败后的手动重试仍可用，且继续先绘制遮罩再 reload。

通知页不再在切换时执行主题 JS/动画帧探测，仅记录 Flutter 主题变化和原生渲染进程事件。
其他 WebView 保留 `0015` 的一次性主题探测；`NoticeLayout` 继续记录正常导航和手动重试的准备失败。
这些日志不采集 HTML、输入内容或完整查询 URL。`0018` 本身只移除了主题自动刷新和探测；
用户后续仍反馈加载，继续只读检查实际构建依赖后发现下述原生重建路径。

### 原生节点在主题变化时被重建

当前嵌入层的 `FlutterAbility.onConfigurationUpdate()` 在传递 Flutter brightness 后，调用
`FlutterAbilityAndEntryDelegate.changeColorMode()`。后者对平台视图执行 `nodeController.rebuild()`，
`EmbeddingNodeController.makeNode()` 无条件新建 BuilderNode。CPF `OhosWebView.aboutToDisappear()`
又会在未使用 keepAlive 时 dispose WebBuilderNode 并释放 Web 资源。因此 Dart Widget 即使被保留，
主题变化仍可能替换其下面的原生组件，产生重新加载或控制器失效；这与系统浏览器的接入路径不同。

历史实现（嵌入层与插件补丁均已于 2026-09-22 移除）：仅把主题分支改为调用已有 BuilderNode 的
`updateConfiguration()`，不改变尺寸或渲染表面变化等其他重建入口。API 26 的声明明确该接口
用于传递系统配置变化。另在 CPF WebView 的 `onWillApplyTheme()` 中通知内部持有的 WebBuilderNode，
使其使用现有 Web 和控制器更新配置。原生 AUTO 及现有深浅 CSS 继续负责配色。

Hvigor 从本次选择的原始 HAR 生成副本内的补丁包，校验包版本和源文件哈希，并统一替换所有模块的
嵌入层 override。没有写入本机 SDK、修改引擎二进制或放宽源码匹配条件。
原有导航加载器保持不变，不通过屏蔽所有同 URL 的加载回调来隐藏真正的刷新。
代码与构建接入完成后，2026-09-16 用户确认这一部分正常运行，已据此关闭原生主题切换问题。
该运行证据来自用户反馈；代理没有执行补丁应用或构建。首次主题、前后台和尺寸变化等
未逐项确认的场景仍在第四阶段收尾清单中。

## 全部 WebView 边缘回弹

Dart 默认 `overScrollMode = IF_CONTENT_SCROLLS`，当前 OH 参数解析将其值 1 与 ALWAYS 的值 0
都映射为 ArkWeb `OverScrollMode.ALWAYS`。用户要求扩展到本应用全部鸿蒙 WebView，
现将 `0014` 中按通知来源设置回弹的逻辑移至共用 `DownloadWebView`：先复制调用方的设置，
再统一设置 `OverScrollMode.NEVER`，传给底层 WebView；不改写调用方的设置对象。

源码审查确认当前原生 WebView 创建入口只有通知组件和附件验证码窗口，均在 `0004` 中改为
使用 `DownloadWebView`；三个通知页及志愿四川共用通知组件，因此本次配置覆盖当前全部入口。
后续新增 WebView 也应经过该共用组件，保持策略统一。
关闭边缘效果通过原生参数实现，不添加触摸事件拦截。普通纵向滚动、宽表格局部横向滚动、
志愿四川交互及附件验证码操作的真机效果待验收。

## 青春川大分页原生确认框

用户明确弹窗由鸿蒙原生显示，正文为空，带“确定/取消”按钮。
当前插件 `InAppWebViewClient.ets:656` 的 `tryHandleBeforeUnloadNavigationPolyfill` 在页面注册过
`beforeunload` 且主文档目标 URL 变化时，可主动触发 `onJsBeforeUnload(currentUrl, '', ...)`。
应用未接管该回调时，约第 2831 行调用 `AlertDialog.show`，空字符串成为提示正文。
这条源码路径与用户现象高度吻合，现场回调类型仍需后续验证。

此兼容逻辑仅判断注册过离页监听，并未确认该监听实际要求取消离页。
`0015` 已接入 `onJsBeforeUnload`，同时要求当前组件是青春川大通知页、事件来源主机为
`tuanwei.scu.edu.cn`、消息为空，才返回 `handledByClient: true` 和 `CONFIRM`，由插件直接继续导航。
有正文的离页提示、其他站点或页面保留插件原有处理；页面已销毁或回调异常则取消旧请求。
普通 `onJsConfirm` 仅记录类型和消息是否为空，存续页面仍使用原生确认行为。
因此若现场实际上触发普通 confirm，可由日志明确区分，不把所有业务确认都自动放行。
本次完成定向处理代码，分页无需弹框的真机结果待用户确认。

## 完成记录

2026-09-16 用户确认第四阶段全部剩余部分无问题，以下验收项据此标记通过。

- [x] 在共用 WebView 中全局禁用边缘回弹，已获用户确认。
- [x] 三个通知页使用 ArkWeb 原生 AUTO 跟随系统，保留上游两套 CSS 和教务处搜索框动态媒体查询；移除网页属性方案。
- [x] 青春川大空消息离页确认的限定处理；代码完成。
- [x] 修正 WebView 包装对象与原生视图的生命周期，移除重复释放，并增加有时限的主题切换诊断。
- [x] 三个通知页统一首帧遮罩、文档开始隐藏，以及布局稳定后展示；代码完成。
- [x] 真机确认首次打开、分页、搜索、返回及退出重进不闪现原网页或中间布局，失败可重试。
- [x] 移除主题自动刷新和通知页主题 JS 探测；切换不重复美化、不启动加载器，保留手动刷新及其遮罩。
- [x] 修正嵌入层主题分支的原生节点重建，补齐内部 WebBuilderNode 的配置更新，并接入副本内 HAR 补丁；代码完成。
- [x] 原生主题切换修复运行通过；依据 2026-09-16 用户“这个部分正常运行了”的反馈，关闭已显示网页切换主题时刷新、卡住及 Load Failed 的问题。
- [x] 补充确认首次深浅主题、连续快速切换、返回前台及旋转/尺寸变化的表现。
- [x] 用户真机验证全部入口的滚动、主题、分页、返回、验证码及附件，以及青春川大首帧遮罩和布局。

## 插件源码依据

下列路径相对于上述锁定提交的 CPF 仓库；本机只读镜像位于 `ohos/build/plugin-audit/inappwebview/`。

| 源码 | 关键位置 |
| --- | --- |
| `flutter_inappwebview_platform_interface/lib/src/in_app_webview/in_app_webview_settings.dart` | 521–531 行：useWideViewPort 语义和 Android 支持声明；1876 行：forceDark 默认 OFF；1881 行：概览模式默认开启 |
| `flutter_inappwebview_android/android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InAppWebView.java` | 316 行：Android 设置视口宽度参数 |
| `flutter_inappwebview_ohos/ohos/src/main/ets/components/plugin/webview/in_app_webview/InAppWebViewSettings.ets` | 33 行：概览默认开启；54 行：深色默认关闭；133 行：概览参数映射；205–216 行：深色参数映射；未实现 useWideViewPort |
| `flutter_inappwebview_ohos/ohos/src/main/ets/components/plugin/webview/in_app_webview/WebNodeController.ets` | 156 行：overviewModeAccess；178–179 行：darkMode / forceDarkAccess |
| `flutter_inappwebview/lib/src/in_app_webview/in_app_webview.dart` | `InAppWebView.platform` 及 `_InAppWebViewState` 的 build/dispose 所有权 |
| `flutter_inappwebview_ohos/lib/src/in_app_webview/in_app_webview.dart` | 296 行：平台对象持有控制器；391 行：原生视图创建时初始化；446 行：dispose |
| `flutter_inappwebview_ohos/ohos/src/main/ets/components/plugin/webview/in_app_webview/InAppWebViewClient.ets` | 656 行：离页导航兼容逻辑；680 行：空消息回调；2831 行附近：原生离页确认框 |

第三阶段四项业务验收已按用户反馈勾选。第四阶段原生主题修复及其余专项均获用户确认，
全部完成记录见 [收尾清单](../phases/phase4.md)。
