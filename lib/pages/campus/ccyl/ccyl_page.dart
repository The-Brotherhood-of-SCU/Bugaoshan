import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/ccyl/activities_tab.dart';
import 'package:bugaoshan/pages/campus/ccyl/my_activities_tab.dart';
import 'package:bugaoshan/pages/campus/ccyl/ordered_activities_tab.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_bind_page.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/injection/injector.dart';

class CcylPage extends StatelessWidget {
  const CcylPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.ccylTitle),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    final tabController = DefaultTabController.of(context);
                    final provider = getIt<CcylProvider>();
                    switch (tabController.index) {
                      case 0:
                        provider.service.searchActivities();
                        break;
                      case 1:
                        provider.service.getMyActivities();
                        break;
                      case 2:
                        provider.service.getOrderedActivities();
                        break;
                    }
                  },
                  tooltip: '刷新',
                ),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(text: l10n.ccylSearchActivities),
                  Tab(text: l10n.ccylMyActivities),
                  Tab(text: l10n.ccylOrderedActivities),
                ],
              ),
            ),
            body: ListenableBuilder(
              listenable: Listenable.merge([
                getIt<ScuAuthProvider>(),
                getIt<CcylProvider>(),
              ]),
              builder: (context, _) {
                final auth = getIt<ScuAuthProvider>();
                final ccyl = getIt<CcylProvider>();
                if (!auth.isLoggedIn) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.ccylLoginRequired,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            },
                            icon: const Icon(Icons.person),
                            label: Text('前往登录'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!ccyl.isLoggedIn) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.ccylBindRequired,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => const CcylBindPage(),
                                    ),
                                  );
                              if (result == true && context.mounted) {
                                getIt<CcylProvider>().service
                                    .searchActivities();
                              }
                            },
                            icon: const Icon(Icons.login),
                            label: Text(l10n.ccylDoBind),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return TabBarView(
                  children: [
                    ActivitiesTab(),
                    MyActivitiesTab(),
                    OrderedActivitiesTab(),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
