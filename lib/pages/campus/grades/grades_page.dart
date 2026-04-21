import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'scheme_scores_tab.dart';
import 'passing_scores_tab.dart';

class GradesPage extends StatefulWidget {
  const GradesPage({super.key});

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [SchemeScoresTab(), PassingScoresTab()];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([
        getIt<ScuAuthProvider>(),
        getIt<GradesProvider>(),
      ]),
      builder: (context, _) {
        final auth = getIt<ScuAuthProvider>();

        return Scaffold(
          appBar: AppBar(title: Text(l10n.gradesStats)),
          body: !auth.isLoggedIn
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.gradesLoginRequired,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _pages[_currentIndex], // 直接显示对应索引的 Widget，无滑动冲突
          bottomNavigationBar: auth.isLoggedIn
              ? BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.list_alt),
                      label: l10n.schemeScores,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.check_circle_outline),
                      label: l10n.passingScores,
                    ),
                  ],
                )
              : null, // 未登录时不显示底部栏
        );
      },
    );
  }
}
