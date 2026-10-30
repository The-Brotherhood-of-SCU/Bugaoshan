import 'dart:async';
import 'dart:io';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/downloads/file_utils.dart';
import 'package:bugaoshan/pages/campus/downloads/notice_downloaded_page.dart';
import 'package:bugaoshan/pages/dev/logs/log_viewer_page.dart';
import 'package:bugaoshan/platform/platform_adapter.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/utils/open_file.dart';
import 'package:bugaoshan/widgets/common/app_directory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OhosAdapter extends PlatformAdapter {
  String? openedPath;
  ResultType result = ResultType.done;

  @override
  bool get isOhos => true;

  @override
  Future<OpenResult> openFile(String path) async {
    openedPath = path;
    return OpenResult(type: result, message: 'test');
  }
}

class _Paths extends PathProviderPlatform {
  _Paths(this.cache, this.documents);
  final String cache;
  final String documents;

  @override
  Future<String?> getTemporaryPath() async => cache;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;

  @override
  Future<String?> getDownloadsPath() async => documents;
}

Widget _wrap(Widget page) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: page,
);

// Filesystem futures run outside the widget test's fake clock.
Future<void> _settleIo(
  WidgetTester tester,
  Future<void> Function() action, {
  Finder? waitFor,
}) async {
  await tester.runAsync(() async {
    await action();
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty &&
          (waitFor == null || waitFor.evaluate().isNotEmpty)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Directory operation did not finish');
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
  late Directory temp;
  late Directory cache;
  late Directory documents;
  late Directory files;
  late PlatformAdapter originalAdapter;
  late PathProviderPlatform originalPaths;
  late _OhosAdapter adapter;
  late AppLogger logger;
  var externalDirectoryCalls = 0;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    getIt.registerSingleton<AppConfigProvider>(
      AppConfigProvider(await SharedPreferences.getInstance()),
    );
    logger = AppLogger();
    getIt.registerSingleton<AppLogger>(logger);
    temp = await Directory.systemTemp.createTemp('app-directory-test-');
    cache = await Directory(p.join(temp.path, 'cache')).create();
    documents = await Directory(p.join(temp.path, 'documents')).create();
    files = await Directory(p.join(temp.path, 'files')).create();
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(cache.path, documents.path);
    originalAdapter = PlatformAdapter.instance;
    adapter = _OhosAdapter();
    PlatformAdapter.instance = adapter;
    externalDirectoryCalls = 0;
    messenger.setMockMethodCallHandler(urlChannel, (_) async {
      externalDirectoryCalls++;
      throw PlatformException(code: 'PRIVATE_DIRECTORY');
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(shareChannel, null);
    messenger.setMockMethodCallHandler(urlChannel, null);
    PlatformAdapter.instance = originalAdapter;
    PathProviderPlatform.instance = originalPaths;
    await getIt.reset();
    logger.dispose();
    await temp.delete(recursive: true);
  });

  testWidgets('OHOS log folder lists rotated logs and exports inside the app', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final logs = await resolveLogDir();
      await File(p.join(logs.path, 'bugaoshan.1.log')).writeAsString('older');
      await File(
        p.join(logs.path, 'bugaoshan-export-1.log'),
      ).writeAsString('export');
      await File(p.join(logs.path, '.internal')).writeAsString('hidden');
    });
    await tester.pumpWidget(_wrap(const LogViewerPage()));
    await tester.pumpAndSettle();
    await _settleIo(
      tester,
      () => tester.tap(find.byTooltip('Open log folder')),
      waitFor: find.byType(AppDirectoryPage),
    );
    expect(find.byType(AppDirectoryPage), findsOneWidget);
    expect(find.text('bugaoshan.1.log'), findsOneWidget);
    expect(find.text('bugaoshan-export-1.log'), findsOneWidget);
    expect(find.text('.internal'), findsNothing);
    expect(externalDirectoryCalls, 0);
  });

  testWidgets('OHOS attachment folder opens the currently selected category', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final name in [kNoticeAttachmentDir, kPartyAttachmentDir]) {
        final directory = await Directory(
          p.join(documents.path, 'Bugaoshan', name),
        ).create(recursive: true);
        await File(p.join(directory.path, '$name.pdf')).writeAsString('pdf');
      }
    });
    await _settleIo(
      tester,
      () => tester.pumpWidget(_wrap(const NoticeDownloadedPage(initialTab: 1))),
    );
    await _settleIo(
      tester,
      () => tester.tap(find.byTooltip('Open folder')),
      waitFor: find.byType(AppDirectoryPage),
    );
    expect(find.byType(AppDirectoryPage), findsOneWidget);
    expect(find.text('$kPartyAttachmentDir.pdf'), findsOneWidget);
    expect(find.text('$kNoticeAttachmentDir.pdf'), findsNothing);
    expect(externalDirectoryCalls, 0);
  });

  testWidgets(
    'refresh discovers new files and hides internal files and directories',
    (tester) async {
      await _settleIo(
        tester,
        () => tester.pumpWidget(
          _wrap(AppDirectoryPage(directory: files, title: 'Files')),
        ),
      );
      expect(find.text('No files in this folder'), findsOneWidget);
      await tester.runAsync(() async {
        await File(p.join(files.path, 'new.log')).writeAsString('new');
        await File(p.join(files.path, '.index.json')).writeAsString('{}');
        await Directory(p.join(files.path, 'nested')).create();
      });
      await _settleIo(tester, () => tester.tap(find.byTooltip('Refresh')));
      expect(find.text('new.log'), findsOneWidget);
      expect(find.text('.index.json'), findsNothing);
      expect(find.text('nested'), findsNothing);
    },
  );

  testWidgets('file open uses the host adapter and reports native failures', (
    tester,
  ) async {
    final file = File(p.join(files.path, 'course.pdf'));
    await tester.runAsync(() => file.writeAsString('pdf'));
    await _settleIo(
      tester,
      () => tester.pumpWidget(
        _wrap(AppDirectoryPage(directory: files, title: 'Files')),
      ),
    );
    await tester.tap(find.text('course.pdf'));
    await tester.pumpAndSettle();
    expect(adapter.openedPath, file.path);
    adapter.result = ResultType.noAppToOpen;
    await tester.tap(find.text('course.pdf'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not open this file. Try sharing it to another app.'),
      findsOneWidget,
    );
    expect(
      logger.entries.any(
        (entry) =>
            entry.tag == 'AppDirectoryPage' && entry.level == LogLevel.error,
      ),
      isTrue,
    );
  });

  testWidgets(
    'sharing retains a snapshot even when the source log is removed',
    (tester) async {
      final file = File(p.join(files.path, 'bugaoshan.1.log'));
      await tester.runAsync(() => file.writeAsString('retained log'));
      final shared = Completer<String>();
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        final paths = (call.arguments as Map)['paths'] as List;
        final path = paths.single as String;
        await file.delete();
        shared.complete(path);
        return 'success';
      });
      await _settleIo(
        tester,
        () => tester.pumpWidget(
          _wrap(AppDirectoryPage(directory: files, title: 'Files')),
        ),
      );
      await _settleIo(tester, () => tester.tap(find.byTooltip('Share')));
      await tester.runAsync(() async {
        final path = await shared.future.timeout(const Duration(seconds: 5));
        expect(path, isNot(file.path));
        expect(p.basename(path), 'bugaoshan.1.log');
        expect(await File(path).readAsString(), 'retained log');
        expect(await file.exists(), isFalse);
      });
    },
  );

  testWidgets(
    'a removed directory shows a recoverable error and can be refreshed',
    (tester) async {
      await tester.runAsync(() => files.delete());
      await _settleIo(
        tester,
        () => tester.pumpWidget(
          _wrap(AppDirectoryPage(directory: files, title: 'Files')),
        ),
      );
      expect(
        find.text('Could not read this folder. Refresh to try again.'),
        findsOneWidget,
      );
      await tester.runAsync(() => files.create());
      await _settleIo(tester, () => tester.tap(find.byTooltip('Refresh')));
      expect(find.text('No files in this folder'), findsOneWidget);
    },
  );
}
