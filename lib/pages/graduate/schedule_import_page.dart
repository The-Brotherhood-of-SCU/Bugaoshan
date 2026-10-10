import 'dart:async';
import 'dart:collection';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';
import 'package:bugaoshan/services/api/gs_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/graduate_schedule_capture.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/graduate_schedule_parser.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:bugaoshan/widgets/webview/webview_unsupported_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:os_type/os_type.dart';

/// 直连失败的原因分类，决定失败态的文案与可用动作。
enum _DirectFailureKind {
  /// ehall 会话未建立 / 统一认证会话已过期。
  unauthenticated,

  /// 网络 / 接口 / 解析等其它错误。
  other,

  /// 兜底占位（fetchSchedule 返回空课表时与 [other] 同展示）。
  unknown,
}

/// 研究生课表导入。
///
/// **直连为主**：进入页面先尝试用 SCU 统一认证会话直连 `xspkjgcx.do`
/// （[GsApiService.fetchSchedule]），成功则直接展示结果并导入，无需打开
/// 网页；学期第 1 周周一由首次上课日期（SCSKRQ）反推，每节起止时刻由
/// 行内 KSSJ/JSSJ 派生（缺省时按校区预置）。失败按原因分类展示：未登录
/// 给「前往登录」（应用自带认证体系）+ 重试，其余给错误信息 + 重试。
///
/// **WebView 只作应急**：用户在失败态主动点击「应急网页抓取」才加载
/// [kGsSchedulePageUrl]，并在文档开始前注入 [kGraduateScheduleCaptureScript]，
/// 由页面自己去取课表数据时顺手把响应体记下来；Dart 侧轮询取走，用
/// [graduateCoursesFromCapturedJson] 识别出课程，再写进课表。应急方案需
/// 用户在页面内登录一次 ehall，信息也不如直连全面，仅直连不可用时使用。
class GraduateScheduleImportPage extends StatefulWidget {
  const GraduateScheduleImportPage({super.key});

  @override
  State<GraduateScheduleImportPage> createState() =>
      _GraduateScheduleImportPageState();
}

class _GraduateScheduleImportPageState
    extends State<GraduateScheduleImportPage> {
  static const String _tag = 'GraduateScheduleImportPage';

  /// 轮询间隔：够快能及时反馈，又不会把 WebView 打满。
  static const Duration _pollInterval = Duration(milliseconds: 1500);

  InAppWebViewController? _controller;
  Timer? _pollTimer;
  List<GraduateCaptureEntry> _entries = const [];
  List<Course> _courses = const [];
  List<String> _captureUrls = const [];
  bool _pageLoading = true;
  bool _importing = false;

  /// 直连状态：进行中（`_directPhase`）/ 成功（`_directAvailable`）/
  /// 失败（`_directFailureMessage` 非空，见 [_DirectFailureKind]）。
  bool _directPhase = true;
  bool _directAvailable = false;
  DateTime? _directSemesterStart;

  /// 直连失败的原因分类与原文，用于失败态 UI。
  _DirectFailureKind _directFailureKind = _DirectFailureKind.unknown;
  String? _directFailureMessage;

  /// 用户主动点了「应急网页抓取」——渲染 WebView，不再回到失败态。
  bool _manualWebView = false;

  /// 直连成功时由 KSSJ/JSSJ 派生的课表专属时刻表（应急路径为 null）。
  List<TimeSlot>? _directTimeSlots;

  @override
  void initState() {
    super.initState();
    _tryDirectFetch();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// 直连拉取课表；失败按原因分类，不再静默跳 WebView。
  Future<void> _tryDirectFetch() async {
    setState(() {
      _directPhase = true;
      _directAvailable = false;
      _directFailureMessage = null;
      _manualWebView = false;
    });
    try {
      final api = getIt<GsApiService>();
      final data = await api.fetchSchedule();
      if (!mounted) return;
      if (data.courses.isEmpty) {
        setState(() {
          _directPhase = false;
          _directFailureKind = _DirectFailureKind.other;
          _directFailureMessage = null;
        });
        return;
      }

      DateTime? semesterStart;
      try {
        final term = await api.latestSemesterCode();
        if (term != null) {
          semesterStart = semesterStartMondayFromFirstClassRows(
            await api.fetchFirstClassRows(term),
          );
        }
      } catch (e) {
        // 学期起始日推算失败不影响导入，仅退回「本周一」近似。
        AppLog.w(_tag, '直连学期起始日推算失败：$e');
      }

      if (!mounted) return;
      setState(() {
        _directPhase = false;
        _directAvailable = true;
        _courses = data.courses;
        _directTimeSlots = data.timeSlots;
        _directSemesterStart = semesterStart;
      });
      AppLog.i(_tag, '直连获取课表成功：${data.courses.length} 门课');
    } on ScuException catch (e) {
      AppLog.i(_tag, '直连获取课表失败：$e');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _directPhase = false;
        _directFailureKind = e is UnauthenticatedException
            ? _DirectFailureKind.unauthenticated
            : _DirectFailureKind.other;
        _directFailureMessage = l10n == null ? null : e.message;
      });
    } catch (e) {
      AppLog.i(_tag, '直连获取课表失败：$e');
      if (!mounted) return;
      setState(() {
        _directPhase = false;
        _directFailureKind = _DirectFailureKind.other;
        _directFailureMessage = null;
      });
    }
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_pollCapture()),
    );
  }

  /// 读取页面里累积的捕获结果；有新数据才重新解析。
  Future<void> _pollCapture() async {
    final controller = _controller;
    if (controller == null || !mounted) return;

    final Object? raw;
    try {
      raw = await controller.evaluateJavascript(
        source: kGraduateScheduleCaptureQuery,
      );
    } catch (e) {
      AppLog.w(_tag, '读取捕获结果失败：$e');
      return;
    }
    if (!mounted) return;

    final entries = graduateCaptureEntriesFrom(raw is String ? raw : null);
    if (entries.length == _entries.length) return;

    final courses = graduateCoursesFromCapturedJson(
      entries.map((e) => e.body).toList(),
    );
    setState(() {
      _entries = entries;
      _courses = courses;
      _captureUrls = {
        for (final entry in entries)
          if (entry.url.isNotEmpty) redactCaptureUrl(entry.url),
      }.toList();
    });
    AppLog.i(_tag, '捕获 ${entries.length} 段响应，识别出 ${courses.length} 门课程');
  }

  Future<void> _reload() async {
    // 应急网页模式：清空捕获状态后重载页面。
    if (_manualWebView) {
      setState(() {
        _entries = const [];
        _courses = const [];
        _captureUrls = const [];
        _pageLoading = true;
      });
      final controller = _controller;
      if (controller == null) return;
      try {
        await controller.evaluateJavascript(
          source: 'window.$kGraduateCaptureGlobal = [];',
        );
        await controller.reload();
      } catch (e) {
        AppLog.w(_tag, '重新加载失败：$e');
      }
      return;
    }
    // 其余状态（进行中 / 成功 / 失败）：刷新 = 重试直连。
    await _tryDirectFetch();
  }

  /// 课表覆盖的最大周数：不少于默认 20 周，课程周次更靠后就跟着放大。
  int _totalWeeksFor(List<Course> courses) {
    var maxEnd = kDefaultTotalWeeks;
    for (final course in courses) {
      if (course.endWeek > maxEnd) maxEnd = course.endWeek;
    }
    return maxEnd;
  }

  Future<void> _import() async {
    if (_courses.isEmpty || _importing) return;

    final l10n = AppLocalizations.of(context)!;
    final provider = getIt<CourseProvider>();
    final scheduleName = l10n.graduateScheduleImportName;
    setState(() => _importing = true);

    // 先定下「目标课表的形状」，同时用它做范围校验与写库。
    // 直连成功时用首次上课日期反推的第 1 周周一；兜底路径退回「本周一」近似。
    final config = ScheduleConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      semesterName: scheduleName,
      semesterStartDate: _directSemesterStart ?? DateTime.now().toMonday(),
      totalWeeks: _totalWeeksFor(_courses),
    );
    // 按课程的主导校区挑时间表（江安 / 望江华西），节数非默认时不改动。
    ScheduleConfig.applyCampusTimeSlotsForCourses(config, _courses);

    // 接口自带的精确作息（KSSJ/JSSJ 派生）优先于预置：显示时间与教务一致。
    // 派生表长度与预置对齐（graduateTimeSlotsFromRows 保证），节数不符时不动。
    final derivedSlots = _directTimeSlots;
    if (derivedSlots != null &&
        derivedSlots.length == config.timeSlots.length) {
      config.timeSlots = List.of(derivedSlots);
    }

    // 借用本科导入的校验标准，但逐条过滤而非中断整次导入。
    final clamped = clampGraduateCourses(
      _courses,
      totalWeeks: config.totalWeeks,
      sectionsPerDay: config.timeSlots.length,
    );
    if (clamped.dropped > 0) {
      AppLog.w(_tag, '丢弃 ${clamped.dropped} 门越界课程（共 ${_courses.length} 门）');
    }
    final courses = clamped.courses;
    if (courses.isEmpty) {
      AppLog.e(_tag, '解析出的 ${_courses.length} 门课程全部越界，放弃导入');
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.graduateScheduleImportFailed)),
      );
      return;
    }

    // 目标课表已存在时是「整表替换」：同名课表里的课程会被全部清空，
    // 且导入完成后会切换过去——先确认一次，避免从课表页入口误触发覆盖。
    final existingId = provider.findScheduleIdByName(scheduleName);
    if (existingId != null) {
      final overwrite = await showYesNoDialog(
        title: l10n.graduateScheduleImportOverwriteTitle,
        content: l10n.graduateScheduleImportOverwriteBody(scheduleName),
      );
      if (!mounted) return;
      if (overwrite != true) {
        setState(() => _importing = false);
        return;
      }
    }

    try {
      if (existingId != null) {
        await provider.replaceScheduleCourses(existingId, courses);
        await provider.switchSchedule(existingId);
      } else {
        await provider.addSchedule(config);
        await provider.replaceScheduleCourses(config.id, courses);
        await provider.switchSchedule(config.id);
      }
      AppLog.i(_tag, '导入完成：${courses.length} 门课程 → $scheduleName');
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.graduateScheduleImportDoneTo(scheduleName)),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      AppLog.e(_tag, '导入失败：$e');
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.graduateScheduleImportFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 直连进行中：整页 loading，不渲染 WebView。
    if (_directPhase) {
      return Scaffold(
        appBar: _buildAppBar(l10n),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 直连成功：只显示结果与导入按钮，无需打开网页。全平台一致。
    if (_directAvailable) {
      return Scaffold(appBar: _buildAppBar(l10n), body: _buildStatusBar(l10n));
    }

    // 直连失败：Web 被跨域限制（ehall 不放行跨域凭据请求，实测 2026-09-15），
    // 且无 WebView 应急手段——如实提示需要原生客户端。
    if (kIsWeb) {
      // preview 分支的 WebViewUnsupportedPage 只接收 title（无 message 参数）
      return WebViewUnsupportedPage(title: l10n.graduateScheduleImport);
    }

    // 用户主动点了「应急网页抓取」：渲染 WebView（鸿蒙无 WebView，给不了）。
    if (_manualWebView && !OS.isHarmony) {
      return Scaffold(appBar: _buildAppBar(l10n), body: _fallbackBody(l10n));
    }

    return _buildDirectFailure(l10n);
  }

  /// 直连失败态：按原因给文案与动作。未登录给「前往登录」（走应用自带的
  /// 统一认证登录页）+ 重试；其余给错误信息 + 重试。WebView 应急入口只在
  /// 有 WebView 的平台显示，且保持不显眼（TextButton）。
  Widget _buildDirectFailure(AppLocalizations l10n) {
    final isHarmony = OS.isHarmony;
    final isUnauthenticated =
        _directFailureKind == _DirectFailureKind.unauthenticated;
    final message = switch (_directFailureKind) {
      _DirectFailureKind.unauthenticated =>
        l10n.graduateScheduleImportSessionExpired,
      _ when isHarmony => l10n.graduateScheduleImportNoWebView,
      _ => l10n.graduateScheduleImportFailed,
    };

    return Scaffold(
      appBar: _buildAppBar(l10n),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                isUnauthenticated
                    ? Icons.lock_outline
                    : Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              // 接口层的原文（如「研教务返回了无法解析的数据」），供对号入座。
              if (!isUnauthenticated && _directFailureMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _directFailureMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (isUnauthenticated)
                FilledButton.icon(
                  onPressed: _openLoginPage,
                  icon: const Icon(Icons.login),
                  label: Text(l10n.graduateScheduleImportGoLogin),
                ),
              OutlinedButton.icon(
                onPressed: _tryDirectFetch,
                icon: const Icon(Icons.refresh),
                label: Text(
                  isUnauthenticated
                      ? l10n.graduateScheduleImportRetryDirect
                      : l10n.retry,
                ),
              ),
              if (!isHarmony) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _manualWebView = true),
                  child: Text(l10n.graduateScheduleImportEmergencyCapture),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 打开应用自带的统一认证登录页；登录完成返回后由用户点「重试」。
  void _openLoginPage() {
    popupOrNavigate(context, const ScuLoginPage());
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n) {
    return AppBar(
      centerTitle: true,
      title: Text(l10n.graduateScheduleImport),
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.close,
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: l10n.retry,
          onPressed: _reload,
        ),
      ],
    );
  }

  /// 兜底路径的页面主体：WebView + 状态栏。
  Widget _fallbackBody(AppLocalizations l10n) {
    return Column(
      children: [
        Expanded(child: _buildWebView()),
        _buildStatusBar(l10n),
      ],
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        InAppWebView(
          onWebViewCreated: _onWebViewCreated,
          initialUrlRequest: URLRequest(url: WebUri(kGsSchedulePageUrl)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            useWideViewPort: true,
            domStorageEnabled: true,
          ),
          initialUserScripts: UnmodifiableListView<UserScript>([
            UserScript(
              source: kGraduateScheduleCaptureScript,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
          ]),
          onLoadStart: (_, _) {
            if (mounted) setState(() => _pageLoading = true);
          },
          onLoadStop: (_, _) {
            if (mounted) setState(() => _pageLoading = false);
          },
          onReceivedError: (_, request, error) {
            AppLog.e(_tag, 'WebView 加载失败：${error.description}');
            if (mounted) setState(() => _pageLoading = false);
          },
        ),
        if (_pageLoading)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildStatusBar(AppLocalizations l10n) {
    final hasCourses = _courses.isNotEmpty;
    final hasEntries = _entries.isNotEmpty;

    final String status;
    if (hasCourses) {
      status = l10n.graduateScheduleImportFound;
    } else if (hasEntries) {
      status = l10n.graduateScheduleImportEmpty;
    } else {
      status = l10n.graduateScheduleImportWaiting;
    }

    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasCourses
                        ? Icons.check_circle_outline
                        : Icons.hourglass_empty,
                    size: 20,
                    color: hasCourses
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (hasCourses)
                    Text(
                      '${_courses.length}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              // 抓到的接口地址（已脱敏）——用于日后改为直接请求。
              if (hasEntries) ...[
                const SizedBox(height: 4),
                Text(
                  _captureUrls.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: hasCourses && !_importing ? _import : null,
                  icon: const Icon(Icons.download_done),
                  label: Text(l10n.graduateScheduleImportAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
