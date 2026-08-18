import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/ccyl/activities_tab.dart';
import 'package:bugaoshan/pages/campus/ccyl/my_activities_tab.dart';
import 'package:bugaoshan/pages/campus/ccyl/ordered_activities_tab.dart';
import 'package:bugaoshan/pages/campus/ccyl/credit_list_page.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_bind_page.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/immersive_dock_service.dart';
import 'package:bugaoshan/widgets/common/immersive_dock_bar.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';

class CcylPage extends StatefulWidget {
  const CcylPage({super.key});

  @override
  State<CcylPage> createState() => _CcylPageState();
}

class _CcylPageState extends State<CcylPage> with RouteAware {
  int _currentIndex = 0;

  /// 是否已接管原生沉浸光感胶囊底栏（仅 ohos 且开启原生底栏时）
  bool _overrideActive = false;

  /// 是否内嵌在首页 IndexedStack（首页 Dock 标签）中
  bool _embedded = false;

  // 固定实例，配合 IndexedStack 保持各 Tab 滚动位置与数据
  final _tabs = const [
    ActivitiesTab(),
    MyActivitiesTab(),
    OrderedActivitiesTab(),
    CreditListPage(),
  ];

  /// 原生底栏标签 id（与 ArkTS 侧 DockIcon 映射对齐）
  static const _dockTabIds = [
    'ccyl_search',
    'ccyl_my',
    'ccyl_ordered',
    'ccyl_credits',
  ];

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  /// 二级页接管原生胶囊底栏：系统级 ImmersiveMaterial 光感材质，
  /// 与首页胶囊完全一致（Flutter 侧 BackdropFilter 达不到该效果）
  void _applyDockOverride(List<String> labels) {
    _overrideActive = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_overrideActive) return;
      ImmersiveDockService.instance.onOverrideTap = _onTabTapped;
      ImmersiveDockService.instance.overrideDock(
        tabs: [
          for (var i = 0; i < labels.length; i++)
            DockTabInfo(id: _dockTabIds[i], label: labels[i], icon: ''),
        ],
        selectedIndex: _currentIndex,
      );
    });
  }

  void _clearDockOverride() {
    if (!_overrideActive) return;
    _overrideActive = false;
    ImmersiveDockService.instance.clearOverride();
  }

  /// 系统级路由感知：仅二级路由模式订阅。三级页面（活动详情、绑定页
  /// 等）压上时本页不 dispose，必须主动让出原生胶囊；返回时恢复。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!ImmersiveDockService.isOhos) return;
    final route = ModalRoute.of(context);
    _embedded = route?.isFirst ?? false;
    if (!_embedded && route != null) {
      ImmersiveDockService.routeObserver.subscribe(this, route);
    }
  }

  /// 三级页面压上：让出原生胶囊（三级页面底部保持系统沉浸）
  @override
  void didPushNext() {
    _clearDockOverride();
  }

  /// 三级页面返回：重新接管原生胶囊（路由返回不触发 build，
  /// 需手动恢复；仅当仍处于已登录已绑定的正常态）
  @override
  void didPopNext() {
    if (!ImmersiveDockService.isOhos) return;
    if (!getIt<AppConfigProvider>().immersiveDockEnabled.value) return;
    if (!getIt<ScuAuthProvider>().isLoggedIn) return;
    if (!getIt<CcylProvider>().isLoggedIn) return;
    final l10n = AppLocalizations.of(context)!;
    _applyDockOverride([
      l10n.ccylSearchActivities,
      l10n.ccylMyActivities,
      l10n.ccylOrderedActivities,
      l10n.ccylMyCredits,
    ]);
  }

  @override
  void dispose() {
    if (!_embedded) {
      ImmersiveDockService.routeObserver.unsubscribe(this);
    }
    _clearDockOverride();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([
        getIt<ScuAuthProvider>(),
        getIt<CcylProvider>(),
      ]),
      builder: (context, _) {
        final auth = getIt<ScuAuthProvider>();
        final ccyl = getIt<CcylProvider>();

        // 未登录校园账号
        if (!auth.isLoggedIn) {
          _clearDockOverride();
          if (auth.isAutoLoggingIn) {
            return Scaffold(
              appBar: AppBar(title: Text(l10n.ccylTitle)),
              body: const AutoLoginLoadingWidget(),
            );
          }
          return Scaffold(
            appBar: AppBar(title: Text(l10n.ccylTitle)),
            body: const LoginRequiredWidget(),
          );
        }

        // 未绑定第二课堂账号
        if (!ccyl.isLoggedIn) {
          _clearDockOverride();
          return Scaffold(
            appBar: AppBar(title: Text(l10n.ccylTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.ccylBindRequired, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // 绑定页（三级页面）上不保留本页的原生胶囊；
                        // 绑定成功后 provider 通知重建时会重新接管
                        _clearDockOverride();
                        await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => const CcylBindPage(),
                          ),
                        );
                        // ActivitiesTab 会在绑定成功后的新 IndexedStack 中自行加载
                        // 并保存结果；这里预拉且丢弃返回值只会造成重复请求。
                      },
                      icon: const Icon(Icons.login),
                      label: Text(l10n.ccylDoBind),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 正常态：底部导航。
        // 关键限定：接管原生胶囊只在「作为二级路由页面」时发生——
        // 若用户在自定义 Dock 栏把第二课堂加为首页标签（本页内嵌在
        // 首页 IndexedStack 中，ModalRoute.isFirst 为 true），底部已经是
        // 首页的原生胶囊，本页子标签必须改为顶部 TabBar，否则覆盖残留
        // 会让 ccyl 胶囊错误地出现在所有页面上（双底栏冲突）。
        final embedded = _embedded;
        final labels = [
          l10n.ccylSearchActivities,
          l10n.ccylMyActivities,
          l10n.ccylOrderedActivities,
          l10n.ccylMyCredits,
        ];
        if (embedded) {
          // 首页 Dock 标签内嵌模式：顶部 TabBar 切换四个子标签，
          // 底部限位由 app 层（首页胶囊可见时注入）负责
          _clearDockOverride();
          return DefaultTabController(
            length: labels.length,
            child: Scaffold(
              appBar: AppBar(
                title: Text(l10n.ccylTitle),
                bottom: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  onTap: _onTabTapped,
                  tabs: [for (final label in labels) Tab(text: label)],
                ),
              ),
              // IndexedStack 保持各子页面状态（滚动位置、已加载数据）
              body: IndexedStack(index: _currentIndex, children: _tabs),
            ),
          );
        }

        // 二级路由模式：ohos 且开启原生底栏时接管 ArkUI 原生沉浸光感
        // 胶囊底栏（系统级 ImmersiveMaterial，与首页完全一致的光感），
        // Flutter 侧不再渲染任何底栏；其余 ohos 场景回退 Flutter 玻璃
        // 胶囊；其他平台保持系统 NavigationBar。
        final useNativeDock = ImmersiveDockService.isOhos &&
            getIt<AppConfigProvider>().immersiveDockEnabled.value;
        final useGlassBar = !useNativeDock && ImmersiveDockService.isOhos;
        final floatBar = useNativeDock || useGlassBar;
        // 注意：本页被三级页面（活动详情等）覆盖时仍可能因 provider
        // 通知而 rebuild，此时路由已不是 current，绝不可重新接管——
        // 否则刚让出的胶囊会被再次推到三级页面上
        final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
        if (useNativeDock && isCurrentRoute) {
          _applyDockOverride(labels);
        } else {
          _clearDockOverride();
        }
        final destinations = [
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: labels[0],
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: labels[1],
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_outline),
            selectedIcon: const Icon(Icons.bookmark),
            label: labels[2],
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment),
            label: labels[3],
          ),
        ];
        return Scaffold(
          appBar: AppBar(title: Text(l10n.ccylTitle)),
          extendBody: floatBar,
          // IndexedStack 保持各子页面状态（滚动位置、已加载数据）不因切换丢失
          body: MediaQuery(
            // 悬浮底栏占位：让各 Tab 的滚动内容底部限位在底栏上方
            data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.of(context).padding.copyWith(
                bottom:
                    MediaQuery.of(context).padding.bottom +
                    (floatBar ? ImmersiveDockService.dockBottomSpace : 0),
              ),
            ),
            child: IndexedStack(index: _currentIndex, children: _tabs),
          ),
          bottomNavigationBar: useNativeDock
              ? null
              : useGlassBar
                  ? ImmersiveDockBar(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: _onTabTapped,
                      destinations: destinations,
                    )
                  : NavigationBar(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: _onTabTapped,
                      destinations: destinations,
                    ),
        );
      },
    );
  }
}
