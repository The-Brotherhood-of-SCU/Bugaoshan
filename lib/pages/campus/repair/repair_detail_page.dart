import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/repair.dart';
import 'package:bugaoshan/providers/zhhq_repair_provider.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';

/// 报修工单详情页。
///
/// 展示工单的完整信息（维修项目/故障描述/故障地址/服务单位/收费类型/
/// 期望时间/工单进度时间线），并根据工单状态提供「撤回」或「评价」操作：
/// - 撤回：调用 `myRepair/withdrawMyRepair`（需先查 `ifAllowWithdrawMyRepair`）
/// - 评价：调用 `visitEvaluateUser/save`（待评价且未评价的工单）
class RepairDetailPage extends StatefulWidget {
  /// 工单 id（列表的 `activeId`）。
  final String ticketId;

  /// 列表页传入的标题（可能为空，由详情回填）。
  final String initialTitle;

  /// 列表页传入的状态（可能为空，由详情回填）。
  final String initialStatus;

  const RepairDetailPage({
    super.key,
    required this.ticketId,
    this.initialTitle = '',
    this.initialStatus = '',
  });

  @override
  State<RepairDetailPage> createState() => _RepairDetailPageState();
}

class _RepairDetailPageState extends State<RepairDetailPage> {
  late final ZhhqRepairProvider _provider;
  RepairTicketDetail? _detail;
  Object? _error;
  bool _allowWithdraw = false;
  bool _loadingWithdrawCheck = false;
  bool _operating = false;

  @override
  void initState() {
    super.initState();
    _provider = getIt<ZhhqRepairProvider>();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await _provider.fetchTicketDetail(id: widget.ticketId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _error = null;
      });
      // 状态为待撤回/处理中时查询是否可撤回
      await _maybeCheckWithdraw(detail);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _maybeCheckWithdraw(RepairTicketDetail detail) async {
    // 仅对未办结的工单查询是否可撤回（已办结/已关闭的工单不需要撤回按钮）
    if (detail.ifComplete == '1') return;
    if (!mounted) return;
    setState(() => _loadingWithdrawCheck = true);
    final allow = await _provider.ifAllowWithdrawRepair(id: detail.id);
    if (!mounted) return;
    setState(() {
      _allowWithdraw = allow;
      _loadingWithdrawCheck = false;
    });
  }

  /// 撤回报修。成功返回 true。
  Future<bool> _withdraw() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.repairWithdraw),
        content: Text(l10n.repairWithdrawConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    setState(() => _operating = true);
    try {
      await _provider.withdrawRepair(id: _detail!.id);
      if (!mounted) return false;
      // 刷新列表，使「我的报修」状态同步为已撤回
      await _provider.loadTickets(force: true);
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.repairWithdrawSuccess)));
      Navigator.of(context).pop(true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.repairWithdrawFailed)));
      return false;
    } finally {
      if (mounted) setState(() => _operating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.repairDetail)),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_error != null) {
      return RetryableErrorWidget(
        errorType: LoadErrorType.loadFailed,
        onRetry: () {
          setState(() => _error = null);
          _load();
        },
      );
    }
    final detail = _detail;
    if (detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final title = detail.projectName.isNotEmpty
        ? detail.projectName
        : widget.initialTitle;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 状态 + 标题
        StyledCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (widget.initialStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppShapes.small),
                      ),
                      child: Text(
                        widget.initialStatus,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 报修信息
        StyledCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(l10n.repairProject, detail.projectName),
                if (detail.content.isNotEmpty)
                  _label(l10n.repairContent, detail.content),
                if (detail.areaName.isNotEmpty || detail.address.isNotEmpty)
                  _label(
                    l10n.repairArea,
                    [
                      detail.areaName,
                      detail.address,
                    ].where((s) => s.isNotEmpty).join(' / '),
                  ),
                if (detail.acceptDeptName.isNotEmpty)
                  _label(l10n.repairServiceUnit, detail.acceptDeptName),
                if (detail.payName.isNotEmpty)
                  _label(l10n.repairPayType, detail.payName),
                if (detail.bookTimeString.isNotEmpty)
                  _label(l10n.repairSchedule, detail.bookTimeString),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 操作按钮
        if (_operatorVisible())
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildOperator(l10n),
          ),
        // 工单进度
        if (detail.logs.isNotEmpty) ...[
          const SizedBox(height: 4),
          StyledCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.repairProgress,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final log in detail.logs) _buildLogItem(log),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _label(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(RepairLogItem log) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.statusName.isNotEmpty)
                  Text(
                    log.statusName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (log.content.isNotEmpty)
                  Text(
                    log.content,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (log.createTime.isNotEmpty)
                  Text(
                    log.createTime,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 是否显示操作按钮：待评价且未评价 → 评价；否则若允许撤回 → 撤回。
  bool _operatorVisible() {
    final detail = _detail;
    if (detail == null) return false;
    final pendingEvaluate = detail.status == '4' && detail.ifCommont == '0';
    if (pendingEvaluate && detail.finishedInfo != null) return true;
    return _allowWithdraw;
  }

  Widget _buildOperator(AppLocalizations l10n) {
    final detail = _detail!;
    final pendingEvaluate = detail.status == '4' && detail.ifCommont == '0';
    if (pendingEvaluate && detail.finishedInfo != null) {
      return FilledButton.icon(
        onPressed: _operating ? null : () => _openEvaluate(l10n),
        icon: const Icon(Icons.star_outline),
        label: Text(l10n.repairEvaluate),
      );
    }
    // 撤回（仅允许时）
    return FilledButton.icon(
      onPressed: _operating || _loadingWithdrawCheck ? null : _withdraw,
      icon: const Icon(Icons.undo),
      label: Text(l10n.repairWithdraw),
    );
  }

  /// 打开评价对话框。
  Future<void> _openEvaluate(AppLocalizations l10n) async {
    final detail = _detail!;
    final repairId = detail.finishedInfo?.repairId ?? '';
    if (repairId.isEmpty) return;
    if (!mounted) return;

    // 先加载评价项（维修质量/维修态度/维修速度，含 id/weight）
    final projects = await _provider.fetchEvaluateProjects();
    if (!mounted) return;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.repairEvaluateFailed)));
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EvaluateDialog(
        projects: projects,
        onConfirm: (common, content) async {
          await _provider.evaluateRepair(
            repairId: repairId,
            common: common,
            content: content,
          );
          return true;
        },
      ),
    );
    if (result == true && mounted) {
      // 评价成功：刷新列表并返回
      await _provider.loadTickets(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.repairEvaluateSuccess)));
      Navigator.of(context).pop(true);
    }
  }
}

/// 评价对话框：逐项星级评分（对齐前端「维修质量/维修态度/维修速度」）
/// + 可选评价内容。
///
/// 提交的 `common` 数组为评价项完整对象（`id`/`name`/`weight`/`star`），
/// 与前端 `GetProjectList` 返回结构与 `VisitEvaluateUser` 请求体一致。
class _EvaluateDialog extends StatefulWidget {
  final List<RepairEvaluateProject> projects;
  final Future<bool> Function(List<Map<String, dynamic>> common, String content)
  onConfirm;

  const _EvaluateDialog({required this.projects, required this.onConfirm});

  @override
  State<_EvaluateDialog> createState() => _EvaluateDialogState();
}

class _EvaluateDialogState extends State<_EvaluateDialog> {
  /// 每项评价的星级（默认 5 星），key 为评价项 id。
  late final Map<String, int> _scores;
  final _contentController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _scores = {for (final p in widget.projects) p.id: 5};
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// 构建提交用的 common 数组（评价项完整对象 + star 评分）。
  List<Map<String, dynamic>> _buildCommon() {
    return [
      for (final p in widget.projects)
        {
          'id': p.id,
          'name': p.name,
          'weight': p.weight,
          'star': _scores[p.id] ?? 5,
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.repairEvaluate),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 逐项评价（维修质量/维修态度/维修速度等）
              for (final project in widget.projects)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _scores[project.id] = i),
                          iconSize: 26,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            i <= (_scores[project.id] ?? 0)
                                ? Icons.star
                                : Icons.star_border,
                            color: i <= (_scores[project.id] ?? 0)
                                ? Colors.amber
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.repairEvaluateHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final ok = await widget.onConfirm(
        _buildCommon(),
        _contentController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(ok);
    } catch (e) {
      // 评价接口失败：不关闭对话框，提示后允许重试
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.repairEvaluateFailed),
          ),
        );
        setState(() => _submitting = false);
      }
    }
  }
}
