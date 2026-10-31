import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(prefs);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('StudentTypeSetting updates state and persists to SharedPreferences', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final type = ref.watch(studentTypeSettingProvider);
              return Text(type.name, textDirection: TextDirection.ltr);
            },
          ),
        ),
      ),
    );

    expect(find.text('undergraduate'), findsOneWidget);

    final element = tester.element(find.byType(Consumer));
    final container = ProviderScope.containerOf(element);
    container.read(studentTypeSettingProvider.notifier).update(StudentType.graduate);
    await tester.pump();

    expect(find.text('graduate'), findsOneWidget);
    expect(prefs.getInt('studentType'), StudentType.graduate.index);

    container.read(studentTypeSettingProvider.notifier).update(StudentType.undergraduate);
    await tester.pump();

    expect(find.text('undergraduate'), findsOneWidget);
    expect(prefs.getInt('studentType'), StudentType.undergraduate.index);
  });

  testWidgets('VisibleDockIdsSetting reflects updates and persists to SharedPreferences', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final ids = ref.watch(visibleDockIdsSettingProvider);
              return Text(ids.join(','), textDirection: TextDirection.ltr);
            },
          ),
        ),
      ),
    );

    final element = tester.element(find.byType(Consumer));
    final container = ProviderScope.containerOf(element);

    container.read(visibleDockIdsSettingProvider.notifier).update(['course', 'profile']);
    await tester.pump();

    expect(find.text('course,profile'), findsOneWidget);
    expect(prefs.getStringList('visibleDockIds'), ['course', 'profile']);
  });
}
