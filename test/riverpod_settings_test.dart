import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late AppConfigProvider appConfig;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(prefs);

    appConfig = AppConfigProvider(prefs);
    await appConfig.init();
    getIt.registerSingleton<AppConfigProvider>(appConfig);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('StudentTypeSetting reflects changes from legacy AppConfig and updates state', (
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

    // Legacy change updates Riverpod Consumer
    appConfig.studentType.value = StudentType.graduate;
    await tester.pump();
    expect(find.text('graduate'), findsOneWidget);

    // Riverpod update updates legacy AppConfig
    final element = tester.element(find.byType(Consumer));
    final container = ProviderScope.containerOf(element);
    container.read(studentTypeSettingProvider.notifier).update(StudentType.undergraduate);
    await tester.pump();

    expect(find.text('undergraduate'), findsOneWidget);
    expect(appConfig.studentType.value, StudentType.undergraduate);
  });

  testWidgets('VisibleDockIdsSetting reflects updates', (tester) async {
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
    expect(appConfig.visibleDockIds.value, ['course', 'profile']);
  });
}
