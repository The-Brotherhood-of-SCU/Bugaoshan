import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/services/download_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('bridge providers resolve instance from getIt', () {
    final downloadManager = DownloadManager();
    getIt.registerSingleton<DownloadManager>(downloadManager);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final resolved = container.read(downloadManagerBridge);
    expect(identical(resolved, downloadManager), isTrue);
  });

  test('bridge providers support overrideWith for tests', () {
    final realManager = DownloadManager();
    final mockManager = DownloadManager();
    getIt.registerSingleton<DownloadManager>(realManager);

    final container = ProviderContainer(
      overrides: [
        downloadManagerBridge.overrideWithValue(mockManager),
      ],
    );
    addTearDown(container.dispose);

    final resolved = container.read(downloadManagerBridge);
    expect(identical(resolved, mockManager), isTrue);
  });

  testWidgets('ConsumerWidget can read bridge provider within ProviderScope', (
    tester,
  ) async {
    final downloadManager = DownloadManager();
    getIt.registerSingleton<DownloadManager>(downloadManager);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final manager = ref.watch(downloadManagerBridge);
              return Text(
                'Tasks: ${manager.tasks.length}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Tasks: 0'), findsOneWidget);
  });
}
