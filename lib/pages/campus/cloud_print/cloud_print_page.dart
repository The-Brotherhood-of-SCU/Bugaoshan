import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/cloud_print.dart';
import 'package:bugaoshan/providers/cloud_print_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/campus/cloud_print_pods.dart';
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
part 'cloud_print_preview_dialog.dart';

/// 批量打印、待打印任务和扫描文档共用原生会话与响应式页面。
class CloudPrintPage extends ConsumerStatefulWidget {
  const CloudPrintPage({super.key});
  @override
  ConsumerState<CloudPrintPage> createState() => _CloudPrintPageState();
}

class _CloudPrintPageState extends ConsumerState<CloudPrintPage>
    with SingleTickerProviderStateMixin {
  static const _tag = 'CloudPrintPage';
  late final TabController _tabs;
  late CloudPrintProvider _provider;
  final _pages = PageController();
  late bool _wasLoggedIn;
  final Set<int> _selectedScans = {};
  final Set<int> _selectedJobs = {};
  @override
  void initState() {
    super.initState();
    _wasLoggedIn = ref.read(scuAuthProviderBridge).isLoggedIn;
    _tabs = TabController(length: 3, vsync: this)..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!ref.read(scuAuthProviderBridge).isLoggedIn) return;
    final provider = ref.read(cloudPrintProvider);
    if (_tabs.index == 1 &&
        !provider.loadingJobs &&
        provider.jobs.isEmpty &&
        !provider.jobsFailed) {
      unawaited(provider.refreshJobs());
    }
    if (_tabs.index == 2 &&
        !provider.loadingScans &&
        provider.scans.isEmpty &&
        !provider.scansFailed) {
      unawaited(provider.refreshScans());
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scuAuthProviderBridge, (_, next) {
      if (_wasLoggedIn != next.isLoggedIn) {
        _wasLoggedIn = next.isLoggedIn;
        _selectedScans.clear();
        _selectedJobs.clear();
        _onTabChanged();
        if (next.isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pages.hasClients) _pages.jumpToPage(_tabs.index);
          });
        }
      }
    });

    final auth = ref.watch(scuAuthProviderBridge);
    _provider = ref.watch(cloudPrintProvider);
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
      builder: (_) => _CloudPrintOptionsSheet(
        initial: item?.options ?? _provider.defaults,
        title: item == null
            ? l10n.cloudPrintSharedSettings
            : l10n.cloudPrintFileSettings,
      ),
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

  String _paperLabel(Set<int> ids, AppLocalizations l10n) {
    if (ids.length > 1) return 'A4/A3';
    return switch (ids.first) {
      9 => 'A4',
      8 => 'A3',
      _ => l10n.cloudPrintOriginal,
    };
  }

  /// 与服务端列表模板一致：纸型 · 颜色 · 单双面 · 页数份数。状态码不展示给用户。
  String _jobSummary(CloudPrintJob job, AppLocalizations l10n) => [
    if (job.paperIds.isNotEmpty) _paperLabel(job.paperIds, l10n),
    job.colored ? l10n.cloudPrintFullColor : l10n.cloudPrintMono,
    switch (job.duplex) {
      CloudPrintDuplex.longEdge => l10n.cloudPrintLongEdge,
      CloudPrintDuplex.shortEdge => l10n.cloudPrintShortEdge,
      CloudPrintDuplex.simplex => l10n.cloudPrintSimplex,
    },
    l10n.cloudPrintJobInfo(job.pages, job.copies),
  ].join(' · ');

  Future<void> _previewJob(CloudPrintJob job) => showDialog<void>(
    context: context,
    builder: (_) => _CloudPrintPreviewDialog(provider: _provider, job: job),
  );

  Future<void> _deleteJob(CloudPrintJob job, AppLocalizations l10n) async {
    final generation = _provider.sessionGeneration;
    final confirmed = await _confirmDelete(
      l10n.cloudPrintDelete,
      l10n.cloudPrintDeleteConfirm(job.name),
      l10n,
    );
    if (!confirmed) return;
    final result = await _provider.deleteJobs([job]);
    if (!mounted || generation != _provider.sessionGeneration) return;
    _snackDeleteResult(result.deleted, result.failed, l10n);
  }

  Future<void> _deleteSelectedJobs(AppLocalizations l10n) async {
    final generation = _provider.sessionGeneration;
    final targets = _provider.jobs
        .where((job) => _selectedJobs.contains(job.id))
        .toList();
    if (targets.isEmpty) return;
    final confirmed = await _confirmDelete(
      l10n.cloudPrintDelete,
      l10n.cloudPrintDeleteSelectedConfirm(targets.length),
      l10n,
    );
    if (!confirmed) return;
    final result = await _provider.deleteJobs(targets);
    if (!mounted || generation != _provider.sessionGeneration) return;
    _selectedJobs.removeWhere(
      (id) => !_provider.jobs.any((job) => job.id == id),
    );
    _snackDeleteResult(result.deleted, result.failed, l10n);
  }

  Future<bool> _confirmDelete(
    String title,
    String message,
    AppLocalizations l10n,
  ) async {
    final generation = _provider.sessionGeneration;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return confirmed == true &&
        mounted &&
        generation == _provider.sessionGeneration;
  }

  void _snackDeleteResult(int deleted, int failed, AppLocalizations l10n) {
    if (failed == 0) {
      _snack(l10n.cloudPrintDeletedCount(deleted));
    } else {
      _snack(l10n.cloudPrintDeletePartial(deleted, failed));
    }
  }

  Widget _jobsTab(AppLocalizations l10n) => RefreshIndicator(
    onRefresh: _provider.refreshJobs,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: withSystemBottomInset(context, const EdgeInsets.all(16)),
      children: [
        _hint(l10n.cloudPrintHint),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _provider.loadingJobs ? null : _provider.refreshJobs,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.refresh),
            ),
            OutlinedButton.icon(
              onPressed: _selectedJobs.isEmpty
                  ? null
                  : () => _deleteSelectedJobs(l10n),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.cloudPrintDeleteSelected(_selectedJobs.length)),
            ),
          ],
        ),
        if (_provider.jobs.isNotEmpty)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.cloudPrintSelectAll),
            value: _selectedJobs.length == _provider.jobs.length,
            onChanged: (value) => _update(() {
              _selectedJobs.clear();
              if (value == true) {
                _selectedJobs.addAll(_provider.jobs.map((job) => job.id));
              }
            }),
          ),
        if (_provider.loadingJobs) const LinearProgressIndicator(),
        if (_provider.jobsFailed) _hint(l10n.cloudPrintLoadFailed),
        if (!_provider.loadingJobs &&
            !_provider.jobsFailed &&
            _provider.jobs.isEmpty)
          _hint(l10n.cloudPrintJobsEmpty),
        for (final job in _provider.jobs)
          StyledCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                CheckboxListTile(
                  value: _selectedJobs.contains(job.id),
                  onChanged: (value) => _update(() {
                    if (value == true) {
                      _selectedJobs.add(job.id);
                    } else {
                      _selectedJobs.remove(job.id);
                    }
                  }),
                  title: Text(
                    job.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_jobSummary(job, l10n)}\n'
                    '${l10n.cloudPrintJobCreated(job.createdDateLabel, job.createdTimeLabel)} · #${job.id}',
                  ),
                  isThreeLine: true,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => _previewJob(job),
                      icon: const Icon(Icons.visibility_outlined),
                      label: Text(l10n.cloudPrintPreview),
                    ),
                    TextButton.icon(
                      onPressed: () => _deleteJob(job, l10n),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.cloudPrintDelete),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
