import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_activity_phase.dart';
import 'package:bugaoshan/pages/campus/ccyl/widgets/ccyl_phase_chip.dart';

Future<void> _pump(WidgetTester tester, List<CcylActivityPhase> phases) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: CcylPhaseChips(phases: phases)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSingle(WidgetTester tester, CcylActivityPhase phase) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: CcylPhaseChip(phase: phase)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BoxDecoration _decorationOf(WidgetTester tester, String label) {
  final chip = tester.widget<Container>(
    find.ancestor(of: find.text(label), matching: find.byType(Container)),
  );
  return chip.decoration! as BoxDecoration;
}

void main() {
  const singleExpectations = {
    CcylActivityPhase.subscribed: '已预约',
    CcylActivityPhase.available: '可预约',
    CcylActivityPhase.enrolling: '报名中',
    CcylActivityPhase.ongoing: '进行中',
    CcylActivityPhase.notStarted: '未开始',
    CcylActivityPhase.ended: '已结束',
  };

  singleExpectations.forEach((phase, label) {
    testWidgets('状态 $label 渲染对应文案', (tester) async {
      await _pumpSingle(tester, phase);
      expect(find.text(label), findsOneWidget);
    });
  });

  testWidgets('不同标签使用不同底色', (tester) async {
    await _pump(tester, CcylActivityPhase.values.toList().reversed.toList());
    final context = tester.element(find.text('已预约'));
    final scheme = Theme.of(context).colorScheme;

    expect(_decorationOf(tester, '已预约').color, scheme.primaryContainer);
    expect(_decorationOf(tester, '报名中').color, scheme.secondaryContainer);
    expect(_decorationOf(tester, '进行中').color, scheme.tertiaryContainer);
    expect(_decorationOf(tester, '可预约').color, scheme.surfaceContainerHighest);
    expect(_decorationOf(tester, '已结束').color, scheme.inverseSurface);
  });

  testWidgets('未开始使用描边样式与填充标签区分', (tester) async {
    await _pump(tester, [CcylActivityPhase.notStarted]);
    final context = tester.element(find.text('未开始'));
    final scheme = Theme.of(context).colorScheme;
    final decoration = _decorationOf(tester, '未开始');
    expect(decoration.color, isNull);
    expect(decoration.border, isA<Border>());
    expect((decoration.border! as Border).top.color, scheme.outline);
  });

  testWidgets('报名中与进行中同时命中时两个标签并存', (tester) async {
    await _pump(tester, [
      CcylActivityPhase.enrolling,
      CcylActivityPhase.ongoing,
    ]);
    expect(find.text('报名中'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
  });
}
