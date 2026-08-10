import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/service_applications_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:flutter/material.dart';

/// 办事大厅 · 我的申请。
///
/// 展示当前用户的所有已提交事项（`/site/process/inst-list`，status=0 查全部）。
/// 列表项字段来自真实抓包：`app_name`（事项名）、`created`（提交时间）、
/// `inst_status`（中文状态，如"已完成"）。
class MyApplicationsPage extends StatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage> {
  late final ServiceApplicationsProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = getIt<ServiceApplicationsProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaveMyApplications)),
      body: ListenableBuilder(
        listenable: Listenable.merge([getIt<ScuAuthProvider>(), _provider]),
        builder: (context, _) => !getIt<ScuAuthProvider>().isLoggedIn
            ? const LoginRequiredWidget()
            : _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_provider.state == ServiceApplicationsLoadState.idle ||
        _provider.state == ServiceApplicationsLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_provider.state == ServiceApplicationsLoadState.error) {
      return RetryableErrorWidget(
        errorType: _provider.error!,
        onRetry: _provider.refresh,
      );
    }
    if (_provider.items.isEmpty) {
      return _emptyState(l10n);
    }
    return RefreshIndicator(
      onRefresh: _provider.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _provider.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _itemCard(_provider.items[i], l10n),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item, AppLocalizations l10n) {
    final title = (item['app_name'] ?? item['name'] ?? '').toString();
    final created = (item['created'] ?? item['create_time'] ?? '').toString();
    return StyledCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? '请假申请' : title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _statusChip(item, l10n),
            ],
          ),
          if (created.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.leaveSubmitTime}: $created',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(Map<String, dynamic> item, AppLocalizations l10n) {
    // 优先用服务端下发的中文状态（inst_status），兜底映射数字 status。
    final instStatus = (item['inst_status'] ?? '').toString();
    if (instStatus.isNotEmpty) {
      return _chip(instStatus, _colorForStatus(item['status']?.toString()));
    }
    return _chip(
      _labelForStatus(item['status']?.toString(), l10n),
      _colorForStatus(item['status']?.toString()),
    );
  }

  Color _colorForStatus(String? status) {
    return switch (status) {
      '1' || '7' => Colors.orange,
      '0' => Colors.grey,
      '2' || '4' => Colors.green,
      _ => Colors.blueGrey,
    };
  }

  String _labelForStatus(String? status, AppLocalizations l10n) {
    return switch (status) {
      '1' || '7' => l10n.leaveStatusProcessing,
      '0' => l10n.leaveStatusDraft,
      '2' || '4' => l10n.leaveStatusDone,
      _ => status ?? '—',
    };
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppShapes.small),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }

  Widget _emptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.leaveNoApplications,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
