import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/grades/custom_stats_tab.dart';
import 'package:bugaoshan/pages/campus/grades/scheme_scores_tab.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('scheme scores default to main plan and allow plan switching', (
    tester,
  ) async {
    final provider = await _createProvider(
      schemeData: _schemeData(),
      passingData: _passingData(),
    );
    await provider.refreshSchemeScores();
    getIt.registerSingleton(provider);

    await tester.pumpWidget(_testApp(const SchemeScoresTab()));

    expect(find.text('主专业课程'), findsOneWidget);
    expect(find.text('微专业课程'), findsNothing);
    expect(find.byType(SchemeScoreSelector), findsOneWidget);

    await tester.tap(find.byType(SchemeScoreSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.text('电气电子创新设计（微专业）教学计划').last);
    await tester.pumpAndSettle();

    expect(find.text('微专业课程'), findsOneWidget);
    expect(find.text('主专业课程'), findsNothing);
  });

  testWidgets('custom statistics follow the selected scheme', (tester) async {
    final provider = await _createProvider(
      schemeData: _schemeData(),
      passingData: _passingData(),
    );
    await provider.refreshSchemeScores();
    getIt.registerSingleton(provider);

    await tester.pumpWidget(_testApp(const CustomStatsTab()));

    expect(find.text('主专业课程'), findsOneWidget);
    expect(find.text('微专业课程'), findsNothing);
    expect(find.byType(SchemeScoreSelector), findsOneWidget);

    await tester.tap(find.text('主专业课程'));
    await tester.pump();
    expect(find.text('已选 1 门'), findsOneWidget);

    await tester.tap(find.byType(SchemeScoreSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.text('电气电子创新设计（微专业）教学计划').last);
    await tester.pumpAndSettle();

    expect(find.text('微专业课程'), findsOneWidget);
    expect(find.text('主专业课程'), findsNothing);
    expect(find.text('已选 0 门'), findsOneWidget);
  });
}

Widget _testApp(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('zh'),
  home: Scaffold(body: home),
);

Future<GradesProvider> _createProvider({
  required Map<String, dynamic> schemeData,
  required Map<String, dynamic> passingData,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return GradesProvider(
    prefs,
    _FakeZhjwApiService(schemeData, passingData),
    initialUserId: 'account-A',
  );
}

Map<String, dynamic> _schemeData() => {
  'lnList': [
    {
      'cjlx': '电气电子创新设计（微专业）教学计划',
      'cjList': [_courseData('微专业课程')],
    },
    {
      'cjlx': '计算机科学与技术教学计划',
      'cjList': [_courseData('主专业课程')],
    },
  ],
};

Map<String, dynamic> _passingData() => {
  'lnList': [
    {
      'cjlx': '2025-2026学年秋(两学期)',
      'cjList': [_courseData('微专业课程'), _courseData('主专业课程')],
    },
  ],
};

Map<String, dynamic> _courseData(String name) => {
  'courseName': name,
  'courseAttributeName': '必修',
  'credit': '2',
  'cj': '90',
  'courseScore': 90,
  'gradePointScore': 4,
  'gradeName': 'A',
  'academicYearCode': '2025-2026',
  'termName': '秋',
};

class _FakeZhjwApiService implements ZhjwApiService {
  const _FakeZhjwApiService(this.schemeData, this.passingData);

  final Map<String, dynamic> schemeData;
  final Map<String, dynamic> passingData;

  @override
  Future<Map<String, dynamic>> fetchSchemeScores() async => schemeData;

  @override
  Future<Map<String, dynamic>> fetchPassingScores() async => passingData;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
