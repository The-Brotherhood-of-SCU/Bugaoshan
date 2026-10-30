import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/cloud_print.dart';
import 'package:bugaoshan/pages/campus/cloud_print/cloud_print_page.dart';
import 'package:bugaoshan/providers/cloud_print_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/cloud_print_api_service.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';

class _Login extends ChangeNotifier implements ScuAuthProvider {
  bool loggedIn = true;
  @override
  bool get isLoggedIn => loggedIn;
  @override
  bool get isAutoLoggingIn => false;
  void setLogin(bool value) {
    loggedIn = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api implements CloudPrintApiService {
  int reads = 0;
  List<CloudPrintJob> jobs = [];
  final List<int> deleted = [];
  @override
  Future<List<CloudPrintJob>> fetchJobs() async {
    reads++;
    return jobs;
  }

  @override
  Future<void> deleteJob(CloudPrintJob job) async {
    deleted.add(job.id);
    jobs = jobs.where((item) => item.id != job.id).toList();
  }

  @override
  Future<List<CloudScanJob>> fetchScans() async {
    reads++;
    return [
      CloudScanJob.fromJson({
        'dwJobId': 11,
        'szDisplayName': 'Lecture notes.pdf',
        'dwFileSize': 1048576,
        'dwSubmitDate': 20261025,
        'dwSubmitTime': 94512,
      }),
      CloudScanJob.fromJson({
        'dwJobId': 12,
        'szDisplayName': 'Expired document.pdf',
        'dwStatus': 256,
      }),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Picker extends FilePickerPlatform {
  List<PlatformFile> files = [];
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
    // 同时兼容旧版接口和新增 DarwinOptions 的接口；测试不使用平台专属设置。
    Object? darwinOptions,
  }) async {
    expect(type, FileType.custom);
    expect(allowedExtensions, contains('pdf'));
    return files;
  }
}

final class _PickedFile extends PlatformFile {
  _PickedFile(this.name, this.path, this.size);
  @override
  final String name;
  @override
  final String path;
  final int size;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late CloudPrintProvider provider;
  late _Api api;
  late _Login login;
  late _Picker picker;
  late FilePickerPlatform originalPicker;
  final previewKey = GlobalKey();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    temp = await Directory.systemTemp.createTemp('cloudprint-page-test-');
    api = _Api();
    provider = CloudPrintProvider(api);
    login = _Login();
    getIt.registerSingleton<AppLogger>(AppLogger());
    getIt.registerSingleton<CloudPrintProvider>(provider);
    getIt.registerSingleton<ScuAuthProvider>(login);
    originalPicker = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
  });
  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    provider.dispose();
    login.dispose();
    await getIt.reset();
    await temp.delete(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    double width = 390,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // 可选的本地人工视觉检查；普通测试不依赖系统字体或截图文件。
    final fontPath = Platform.environment['CLOUDPRINT_PREVIEW_FONT'];
    if (fontPath != null) {
      await tester.runAsync(() async {
        final loader = FontLoader('CloudPrintPreview')
          ..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
        await loader.load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
    }
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            colorSchemeSeed: Colors.teal,
            fontFamily: fontPath == null ? null : 'CloudPrintPreview',
          ),
          home: RepaintBoundary(key: previewKey, child: const CloudPrintPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (Platform.environment['CLOUDPRINT_PREVIEW_FONT'] == null) return;
    await tester.runAsync(() async {
      final boundary =
          previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final file = File(p.join('build', 'cloud_print_preview', '$name.png'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('未登录不读取业务列表，显示登录入口', (tester) async {
    login.loggedIn = false;
    await pump(tester);
    expect(find.byType(LoginRequiredWidget), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(api.reads, 0);
  });

  testWidgets('原生多选文件进入队列，可只修改其中一个文件的设置', (tester) async {
    await tester.runAsync(() async {
      for (final name in ['Lecture.pdf', 'Worksheet.pdf']) {
        final file = File(p.join(temp.path, name));
        await file.writeAsString('%PDF fixture');
        picker.files.add(_PickedFile(name, file.path, await file.length()));
      }
    });
    await pump(tester, width: 600);
    await tester.runAsync(() async {
      final selected = Completer<void>();
      void onSelected() {
        if (!provider.selecting &&
            provider.queue.length == 2 &&
            !selected.isCompleted) {
          selected.complete();
        }
      }

      provider.addListener(onSelected);
      await tester.tap(find.text('Add files'));
      await selected.future.timeout(const Duration(seconds: 5));
      provider.removeListener(onSelected);
    });
    await tester.pumpAndSettle();
    expect(provider.queue.length, 2);
    expect(find.text('Lecture.pdf'), findsOneWidget);
    await tester.tap(find.text('File print settings').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '3');
    await tester.enterText(find.byType(TextFormField).last, '2-5');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(provider.queue.first.options.copies, 3);
    expect(provider.queue.first.options.pages, '2-5');
    expect(provider.queue.last.options.copies, 1);
    expect(provider.queue.last.options.pages, '');
    expect(provider.defaults.copies, 1);
    expect(tester.takeException(), isNull);
    await screenshot(tester, 'queue');
  });

  for (final width in [320.0, 960.0]) {
    testWidgets('中文 $width 宽：默认设置与长文件名无布局溢出', (tester) async {
      await tester.runAsync(() async {
        final file = File(p.join(temp.path, '很长的课程资料文件名与打印测试文档.pdf'));
        await file.writeAsString('%PDF fixture');
        await provider.addPaths([file.path]);
      });
      await pump(tester, width: width, locale: const Locale('zh'));
      expect(find.textContaining('A4 · 黑白 · 长边双面'), findsWidgets);
      expect(tester.takeException(), isNull);
      await screenshot(tester, 'queue-${width.toInt()}');
      await tester.tap(find.text('本文件打印设置'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '2,5');
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.textContaining('请输入单页或连续范围'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('扫描件可全选，下载只作用于未过期项，过期项可清理', (tester) async {
    await pump(tester, width: 360);
    await tester.tap(find.text('Scans'));
    await tester.pumpAndSettle();
    expect(find.text('Lecture notes.pdf'), findsOneWidget);
    expect(find.textContaining('Expired'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Download selected'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Download selected'),
          )
          .onPressed,
      isNotNull,
    );
    final checkboxes = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    // 全选行 + 两条扫描件（含过期项）都已选中；过期项现在也能选中用于删除。
    expect(checkboxes.where((box) => box.value == true).length, 3);
    expect(checkboxes.last.onChanged, isNotNull);
    expect(find.text('Clean up expired'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await screenshot(tester, 'scans');
    // 在扫描页登出再登录，会再次加载列表。
    login.setLogin(false);
    provider.clear();
    await tester.pumpAndSettle();
    login.setLogin(true);
    await tester.pumpAndSettle();
    expect(api.reads, 2);
    expect(find.text('Lecture notes.pdf'), findsOneWidget);
  });

  testWidgets('待核对文件不能直接重试，必须先显式确认未生成任务', (tester) async {
    await tester.runAsync(() async {
      final file = File(p.join(temp.path, 'uncertain.pdf'));
      await file.writeAsString('%PDF fixture');
      await provider.addPaths([file.path]);
    });
    provider.queue.single.status = CloudPrintQueueStatus.uncertain;
    await pump(tester, width: 600);
    expect(find.text('Upload again'), findsNothing);
    await tester.tap(find.text('I checked: no job was created'));
    await tester.pumpAndSettle();
    expect(provider.queue.single.status, CloudPrintQueueStatus.uncertain);
    await tester.tap(
      find.widgetWithText(FilledButton, 'I checked: no job was created'),
    );
    await tester.pumpAndSettle();
    expect(provider.queue.single.status, CloudPrintQueueStatus.pending);
  });

  testWidgets('打印任务与扫描文档使用同一套选择布局', (tester) async {
    api.jobs = [
      for (final (id, name) in [
        (101, 'Data structures handout.pdf'),
        (102, 'Linear algebra notes.pdf'),
        (103, 'Lab report final.pdf'),
      ])
        CloudPrintJob.fromJson({
          'dwJobId': id,
          'szJobName': name,
          'szAttribe': 'vdup,color,',
          'szPaperDetail': '[{"dwPaperId":9,"szPaperName":"A4"}]',
          'dwPageCount': 4,
          'dwCopyCount': 1,
          'dwCreateDate': 20261025,
          'dwCreateTime': 232000,
        }),
    ];
    await pump(tester, width: 820);
    await tester.tap(find.text('Print jobs'));
    await tester.pumpAndSettle();
    await screenshot(tester, 'jobs');
    expect(find.text('Select all'), findsOneWidget);
    expect(find.text('Delete selected (0)'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(4));
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('Delete selected (3)'), findsOneWidget);

    // 顶栏顺序与扫描页一致：提示 → 操作按钮 → 全选 → 列表。
    await tester.tap(find.text('Scans'));
    await tester.pumpAndSettle();
    await screenshot(tester, 'scans');
    expect(find.text('Select all'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
