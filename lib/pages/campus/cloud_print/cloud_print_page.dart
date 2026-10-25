import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/cloud_print.dart';
import 'package:bugaoshan/providers/cloud_print_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/share_utils.dart';
import 'package:bugaoshan/utils/system_insets.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/widgets/common/swipe_page_view.dart';

part 'cloud_print_upload_tab.dart';
part 'cloud_print_scans_tab.dart';
part 'cloud_print_options_sheet.dart';

/// 批量打印、待打印任务和扫描文档共用原生会话与响应式页面。
class CloudPrintPage extends StatefulWidget {
  const CloudPrintPage({super.key});
  @override
  State<CloudPrintPage> createState() => _CloudPrintPageState();
}

class _CloudPrintPageState extends State<CloudPrintPage>
    with SingleTickerProviderStateMixin {
  static const _tag = 'CloudPrintPage';
  late final TabController _tabs;
  late final CloudPrintProvider _provider;
  late final ScuAuthProvider _auth;
  final _pages = PageController();
  late bool _wasLoggedIn;
  final Set<int> _selectedScans = {};
  @override
  void initState() {
    super.initState();
    _provider = getIt<CloudPrintProvider>();
    _auth = getIt<ScuAuthProvider>()..addListener(_onAuthChanged);
    _wasLoggedIn = _auth.isLoggedIn;
    _tabs = TabController(length: 3, vsync: this)..addListener(_onTabChanged);
  }

  void _onAuthChanged() {
    if (_wasLoggedIn == _auth.isLoggedIn) return;
    _wasLoggedIn = _auth.isLoggedIn;
    _selectedScans.clear();
    _onTabChanged();
    if (_auth.isLoggedIn) {
      // 登录门禁卸载了 PageView，重新挂载时恢复当前标签对应的页面。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(_tabs.index);
      });
    }
  }

  void _onTabChanged() {
    if (!getIt<ScuAuthProvider>().isLoggedIn) return;
    if (_tabs.index == 1 &&
        !_provider.loadingJobs &&
        _provider.jobs.isEmpty &&
        !_provider.jobsFailed) {
      unawaited(_provider.refreshJobs());
    }
    if (_tabs.index == 2 &&
        !_provider.loadingScans &&
        _provider.scans.isEmpty &&
        !_provider.scansFailed) {
      unawaited(_provider.refreshScans());
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _pages.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = getIt<ScuAuthProvider>();
    return ListenableBuilder(
      listenable: Listenable.merge([auth, _provider]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.cloudPrintTitle),
            bottom: auth.isLoggedIn
                ? TabBar(
                    controller: _tabs,
                    tabs: [
                      Tab(text: l10n.cloudPrintQueue),
                      Tab(text: l10n.cloudPrintJobs),
                      Tab(text: l10n.cloudPrintScans),
                    ],
                  )
                : null,
          ),
          body: !auth.isLoggedIn
              ? (auth.isAutoLoggingIn
                    ? const AutoLoginLoadingWidget()
                    : const LoginRequiredWidget())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: SwipePageView(
                      controller: _pages,
                      tabController: _tabs,
                      keepPagesAlive: true,
                      children: [
                        _uploadTab(l10n),
                        _jobsTab(l10n),
                        _scansTab(l10n),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );

  String _optionsSummary(CloudPrintOptions options, AppLocalizations l10n) =>
      '${switch (options.paper) {
        CloudPrintPaper.a4 => 'A4',
        CloudPrintPaper.a3 => 'A3',
        CloudPrintPaper.original => l10n.cloudPrintOriginal,
      }} · '
      '${options.color == CloudPrintColor.color ? l10n.cloudPrintFullColor : l10n.cloudPrintMono} · '
      '${switch (options.duplex) {
        CloudPrintDuplex.longEdge => l10n.cloudPrintLongEdge,
        CloudPrintDuplex.shortEdge => l10n.cloudPrintShortEdge,
        CloudPrintDuplex.simplex => l10n.cloudPrintSimplex,
      }} · '
      '${l10n.cloudPrintSummary(options.copies, options.pages.isEmpty ? l10n.cloudPrintAllPages : options.pages)}';

  String _size(int bytes) => bytes >= 1048576
      ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).ceil()} KB';
  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _update(VoidCallback action) => setState(action);

  Future<void> _settings(
    AppLocalizations l10n, {
    CloudPrintQueueItem? item,
  }) async {
    final generation = _provider.sessionGeneration;
    final options = await showModalBottomSheet<CloudPrintOptions>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) =>
          _CloudPrintOptionsSheet(initial: item?.options ?? _provider.defaults),
    );
    if (options == null ||
        !mounted ||
        generation != _provider.sessionGeneration) {
      return;
    }
    if (item == null) {
      _provider.applyDefaults(options);
    } else {
      _provider.updateOptions(item, options);
    }
  }

  Future<void> _pickFiles(AppLocalizations l10n) async {
    final generation = _provider.sessionGeneration;
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: cloudPrintExtensions,
      );
      if (selection.isEmpty ||
          !mounted ||
          generation != _provider.sessionGeneration) {
        return;
      }
      final report = await _provider.addPaths(
        selection.map((file) => file.path).whereType<String>(),
      );
      if (!mounted || generation != _provider.sessionGeneration) return;
      _snack(
        l10n.cloudPrintSelection(
          report.added,
          report.duplicates,
          report.invalid + selection.where((file) => file.path == null).length,
        ),
      );
    } catch (error, stack) {
      AppLog.e(
        _tag,
        '选择打印文件失败',
        error: const ServiceException('系统文件选择器失败'),
        stackTrace: stack,
      );
      _snack(l10n.cloudPrintPickFailed);
    }
  }

  Future<void> _confirmMissing(
    CloudPrintQueueItem item,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloudPrintUncertain),
        content: Text(l10n.cloudPrintMissingHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cloudPrintMissingConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _provider.requeue(item, confirmedMissing: true);
    }
  }

  Widget _jobsTab(AppLocalizations l10n) => RefreshIndicator(
    onRefresh: _provider.refreshJobs,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: withSystemBottomInset(context, const EdgeInsets.all(16)),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _provider.loadingJobs ? null : _provider.refreshJobs,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.refresh),
          ),
        ),
        _hint(l10n.cloudPrintHint),
        if (_provider.loadingJobs) const LinearProgressIndicator(),
        if (_provider.jobsFailed) _hint(l10n.cloudPrintLoadFailed),
        if (!_provider.loadingJobs &&
            !_provider.jobsFailed &&
            _provider.jobs.isEmpty)
          _hint(l10n.cloudPrintJobsEmpty),
        for (final job in _provider.jobs)
          StyledCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.print_outlined),
              title: Text(
                job.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                l10n.cloudPrintJobInfo(job.pages, job.copies, job.status),
              ),
              trailing: Text('#${job.id}'),
            ),
          ),
      ],
    ),
  );
}
