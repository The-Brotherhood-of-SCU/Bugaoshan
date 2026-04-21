import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'scheme_scores_tab.dart';
import 'passing_scores_tab.dart';

class GradesPage extends StatelessWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.gradesStats),
              bottom: TabBar(
                tabs: [
                  Tab(text: l10n.schemeScores),
                  Tab(text: l10n.passingScores),
                ],
              ),
            ),
            body: ListenableBuilder(
              listenable: Listenable.merge([
                getIt<ScuAuthProvider>(),
                getIt<GradesProvider>(),
              ]),
              builder: (context, _) {
                final auth = getIt<ScuAuthProvider>();
                if (!auth.isLoggedIn) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.gradesLoginRequired,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return const TabBarView(
                  children: [SchemeScoresTab(), PassingScoresTab()],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
