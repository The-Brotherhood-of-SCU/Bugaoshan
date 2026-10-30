import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/cloud_print.dart';
import 'package:bugaoshan/pages/campus/cloud_print/cloud_print_page.dart';
import 'package:bugaoshan/providers/cloud_print_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/scu_backend/cloud_print/cloud_print_api_service.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_logger.dart';

class _Login extends ChangeNotifier implements ScuAuthProvider {
  @override
  bool get isLoggedIn => true;
  @override
  bool get isAutoLoggingIn => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api implements CloudPrintApiService {
  final job = CloudPrintJob.fromJson({
    'dwJobId': 7,
    'szJobName': 'review.pdf',
    'dwPages': 2,
  });
  final scan = CloudScanJob.fromJson({
    'dwJobId': 11,
    'szDisplayName': 'scan.pdf',
  });
  late List<CloudPrintJob> jobs = [job];
  late List<CloudScanJob> scans = [scan];
  final jobReads = Queue<Completer<List<CloudPrintJob>>>();
  final scanReads = Queue<Completer<List<CloudScanJob>>>();
  final deleted = <int>[];
  final previews = <int>[];
  Completer<Uint8List>? previewHold;
  bool failNextPage = true;
  final png = File('assets/icon.png').readAsBytesSync();
  @override
  Future<List<CloudPrintJob>> fetchJobs() async =>
      jobReads.isNotEmpty ? await jobReads.removeFirst().future : List.of(jobs);
  @override
  Future<List<CloudScanJob>> fetchScans() async => scanReads.isNotEmpty
      ? await scanReads.removeFirst().future
      : List.of(scans);
  @override
  Future<void> deleteJob(CloudPrintJob job) async {
    deleted.add(job.id);
    jobs.removeWhere((item) => item.id == job.id);
  }

  @override
  Future<void> deleteScan(CloudScanJob scan) async {
    deleted.add(scan.id);
    scans.removeWhere((item) => item.id == scan.id);
  }

  @override
  Future<Uint8List> previewPage(CloudPrintJob job, int pageNo) async {
    previews.add(pageNo);
    if (pageNo == 2 && failNextPage) {
      throw const ServiceException('temporary failure');
    }
    return previewHold != null ? await previewHold!.future : png;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Api api;
  late CloudPrintProvider provider;
  late _Login login;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    api = _Api();
    provider = CloudPrintProvider(api);
    login = _Login();
    getIt.registerSingleton<AppLogger>(AppLogger());
    getIt.registerSingleton<CloudPrintProvider>(provider);
    getIt.registerSingleton<ScuAuthProvider>(login);
  });
  tearDown(() async {
    provider.dispose();
    login.dispose();
    await getIt.reset();
  });

  Future<void> pumpPage(WidgetTester tester, {bool scans = false}) async {
    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CloudPrintPage(),
        ),
      ),
    );
    await tester.tap(find.text(scans ? 'Scans' : 'Print jobs'));
    await tester.pumpAndSettle();
  }

  for (final staleFirst in [true, false]) {
    test('删除后旧打印列表${staleFirst ? '先' : '后'}返回均不能复活任务', () async {
      provider.jobs = [api.job];
      final stale = Completer<List<CloudPrintJob>>();
      final fresh = Completer<List<CloudPrintJob>>();
      api.jobReads.addAll([stale, fresh]);
      final read = provider.refreshJobs();
      final deletion = provider.deleteJobs([api.job]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.jobs, isEmpty);
      if (staleFirst) {
        stale.complete([api.job]);
        await read;
        expect(provider.loadingJobs, isTrue);
      }
      fresh.complete([]);
      expect((await deletion).deleted, 1);
      if (!staleFirst) {
        stale.complete([api.job]);
        await read;
      }
      expect(provider.jobs, isEmpty);
      expect(provider.loadingJobs, isFalse);
    });

    test('删除后旧扫描列表${staleFirst ? '先' : '后'}返回均不能复活记录', () async {
      provider.scans = [api.scan];
      final stale = Completer<List<CloudScanJob>>();
      final fresh = Completer<List<CloudScanJob>>();
      api.scanReads.addAll([stale, fresh]);
      final read = provider.refreshScans();
      final deletion = provider.deleteScans([api.scan]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.scans, isEmpty);
      if (staleFirst) {
        stale.complete([api.scan]);
        await read;
        expect(provider.loadingScans, isTrue);
      }
      fresh.complete([]);
      expect((await deletion).deleted, 1);
      if (!staleFirst) {
        stale.complete([api.scan]);
        await read;
      }
      expect(provider.scans, isEmpty);
      expect(provider.loadingScans, isFalse);
    });
  }

  for (final scans in [false, true]) {
    for (final batch in [false, true]) {
      testWidgets('${scans ? '扫描' : '打印'}${batch ? '批量' : '单条'}删除确认在会话变化后失效', (
        tester,
      ) async {
        await pumpPage(tester, scans: scans);
        if (batch) {
          await tester.tap(find.text('Select all'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete selected (1)'));
        } else {
          await tester.tap(
            find.widgetWithIcon(TextButton, Icons.delete_outline).first,
          );
        }
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        provider.clear();
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(api.deleted, isEmpty);
      });
    }
  }

  testWidgets('会话变化关闭预览，晚到的旧图像不会显示', (tester) async {
    api.previewHold = Completer<Uint8List>();
    await pumpPage(tester);
    await tester.tap(
      find.widgetWithIcon(TextButton, Icons.visibility_outlined).first,
    );
    await tester.pump();
    provider.clear();
    api.previewHold!.complete(api.png);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('失效预览只关闭自身，保留其上方的新弹窗', (tester) async {
    await pumpPage(tester);
    await tester.tap(
      find.widgetWithIcon(TextButton, Icons.visibility_outlined).first,
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(InteractiveViewer));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('New login')),
      ),
    );
    await tester.pumpAndSettle();
    provider.clear();
    await tester.pumpAndSettle();
    expect(find.text('New login'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('翻页失败可返回缓存页，也可重试当前页', (tester) async {
    await pumpPage(tester);
    await tester.tap(
      find.widgetWithIcon(TextButton, Icons.visibility_outlined).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(api.previews, [1, 2]);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
    await tester.pumpAndSettle();
    api.failNextPage = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(api.previews, [1, 2, 2, 2]);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
