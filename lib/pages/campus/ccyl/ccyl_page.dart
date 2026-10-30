import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/ccyl/activities_tab.dart';
import 'package:bugaoshan/pages/campus/ccyl/my_activities_tab.dart';
import 'package:bugaoshan/pages/campus/ccyl/ordered_activities_tab.dart';
import 'package:bugaoshan/pages/campus/ccyl/credit_list_page.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_bind_page.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/campus/ccyl_pods.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/swipe_page_view.dart';

class CcylPage extends ConsumerStatefulWidget {
  const CcylPage({super.key});

  @override
  ConsumerState<CcylPage> createState() => _CcylPageState();
}

class _CcylPageState extends ConsumerState<CcylPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // 固定实例，配合 SwipePageView 的 keepPagesAlive 保持各 Tab 的
  // 滚动位置与已加载数据，翻页不丢状态。页签数量以本列表为准。
  final _tabs = const [
    ActivitiesTab(),
    MyActivitiesTab(),
    OrderedActivitiesTab(),
    CreditListPage(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(scuAuthProviderBridge);
    final ccyl = ref.watch(ccylAuthNotifierProvider);

    // 未登录校园账号
    if (!auth.isLoggedIn) {
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
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const CcylBindPage(),
                      ),
                    );
                    // 绑定成功后本页会随 CcylAuthNotifier 重建进入正常态，
                    // ActivitiesTab 那时自行加载；这里预拉且丢弃返回值
                    // 只会造成重复请求。
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

    // 正常态：顶部页签
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ccylTitle),
        bottom: TabBar(
          controller: _tabController,
          // 四个入口弃用页面内底栏、改用顶部页签，把底部让给 Home 的
          // 全局 Dock（#376）。这几条文案比其它页的页签长
          // （「我参与的活动」6 字），等分宽度在默认字号下就会裁字，
          // 放大字号更明显，故不做等分：按内容排布并居中。
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: [
            Tab(text: l10n.ccylSearchActivities),
            Tab(text: l10n.ccylMyActivities),
            Tab(text: l10n.ccylOrderedActivities),
            Tab(text: l10n.ccylMyCredits),
          ],
        ),
      ),
      // 翻页后保留各 Tab 的滚动位置与已加载数据
      body: SwipePageView(
        tabController: _tabController,
        keepPagesAlive: true,
        children: _tabs,
      ),
    );
  }
}
