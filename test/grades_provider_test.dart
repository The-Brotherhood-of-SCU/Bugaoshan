import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('grade cache identity requires a token-bound SCU principal', () {
    expect(
      GradesProvider.confirmedUserIdentity(isLoggedIn: true, principal: null),
      isNull,
    );
    expect(
      GradesProvider.confirmedUserIdentity(
        isLoggedIn: false,
        principal: 'account-A',
      ),
      isNull,
    );
    expect(
      GradesProvider.confirmedUserIdentity(
        isLoggedIn: true,
        principal: ' account-A ',
      ),
      'account-A',
    );
  });

  test('grade caches are isolated when switching SCU accounts', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeZhjwApiService();
    final provider = GradesProvider(prefs, api, initialUserId: 'account-A');

    api.schemeData = _scoreData('A-scheme');
    api.passingData = _scoreData('A-passing');
    await provider.refreshSchemeScores();
    await provider.refreshPassingScores();
    expect(provider.schemeScores?.cjlx, 'A-scheme');
    expect(provider.passingScores?.groups.single.label, 'A-passing');

    provider.setUserIdentity('account-B');

    expect(provider.schemeScores, isNull);
    expect(provider.passingScores, isNull);
    expect(provider.schemeState, GradesLoadState.idle);
    expect(provider.passingState, GradesLoadState.idle);

    final restartedAsB = GradesProvider(prefs, api, initialUserId: 'account-B');
    expect(restartedAsB.schemeScores, isNull);
    expect(restartedAsB.passingScores, isNull);

    restartedAsB.setUserIdentity('account-A');
    expect(restartedAsB.schemeScores?.cjlx, 'A-scheme');
    expect(restartedAsB.passingScores?.groups.single.label, 'A-passing');
  });

  test(
    'all schemes are kept and the main scheme is selected by default',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = _FakeZhjwApiService()
        ..schemeData = _multipleSchemeData()
        ..passingData = _scoreData('passing');
      final provider = GradesProvider(prefs, api, initialUserId: 'account-A');

      await provider.refreshSchemeScores();

      expect(provider.schemes.map((scheme) => scheme.cjlx), [
        '电气电子创新设计（微专业）教学计划',
        '计算机科学与技术教学计划',
      ]);
      expect(provider.schemeScores?.cjlx, '计算机科学与技术教学计划');
      expect(provider.schemeScores?.items.single.courseName, '主专业课程');
    },
  );
}

Map<String, dynamic> _scoreData(String label) => {
  'lnList': [
    {'cjlx': label, 'cjList': <Map<String, dynamic>>[]},
  ],
};

Map<String, dynamic> _multipleSchemeData() => {
  'lnList': [
    {
      'cjlx': '电气电子创新设计（微专业）教学计划',
      'zxf': 20,
      'cjList': [_courseData('微专业课程')],
    },
    {
      'cjlx': '计算机科学与技术教学计划',
      'zxf': 160,
      'cjList': [_courseData('主专业课程')],
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
  late Map<String, dynamic> schemeData;
  late Map<String, dynamic> passingData;

  @override
  Future<Map<String, dynamic>> fetchSchemeScores() async => schemeData;

  @override
  Future<Map<String, dynamic>> fetchPassingScores() async => passingData;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
