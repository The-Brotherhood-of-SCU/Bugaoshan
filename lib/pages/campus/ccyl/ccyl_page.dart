import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/ccyl/activities_tab.dart';
import 'package:bugaoshan/pages/campus/ccyl/my_activities_tab.dart';
import 'package:bugaoshan/pages/campus/ccyl/ordered_activities_tab.dart';
import 'package:bugaoshan/pages/campus/ccyl/credit_list_page.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_bind_page.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/injection/injector.dart';

class CcylPage extends StatefulWidget {
  const CcylPage({super.key});

  @override
  State<CcylPage> createState() => _CcylPageState();
}

class _CcylPageState extends State<CcylPage> {
  int _currentIndex = 0;

  // 固定实例，配合 IndexedStack 保持各 Tab 滚动位置与数据
  final _tabs = const [
    ActivitiesTab(),
    MyActivitiesTab(),
    OrderedActivitiesTab(),
    CreditListPage(),
  ];

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
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
          return Scaffold(
            appBar: AppBar(title: Text(l10n.ccylTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.loginRequired, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      icon: const Icon(Icons.person),
                      label: Text(l10n.goToLogin),
                    ),
                  ],
                ),
              ),
            ),
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
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => const CcylBindPage(),
                          ),
                        );
                        if (result == true && context.mounted) {
                          getIt<CcylProvider>().service.searchActivities();
                        }
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

        // 正常态：底部导航
        return Scaffold(
          appBar: AppBar(title: Text(l10n.ccylTitle)),
          // IndexedStack 保持各子页面状态（滚动位置、已加载数据）不因切换丢失
          body: IndexedStack(index: _currentIndex, children: _tabs),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabTapped,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.search_outlined),
                selectedIcon: const Icon(Icons.search),
                label: l10n.ccylSearchActivities,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: l10n.ccylMyActivities,
              ),
              NavigationDestination(
                icon: const Icon(Icons.bookmark_outline),
                selectedIcon: const Icon(Icons.bookmark),
                label: l10n.ccylOrderedActivities,
              ),
              NavigationDestination(
                icon: const Icon(Icons.assignment_outlined),
                selectedIcon: const Icon(Icons.assignment),
                label: l10n.ccylMyCredits,
              ),
            ],
          ),
        );
      },
    );
  }
}
