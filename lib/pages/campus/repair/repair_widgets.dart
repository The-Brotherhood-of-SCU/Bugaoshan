// 本文件是 `repair_page.dart` 的 part：报修页的辅助子 widget。
//
// 包含：我的工单列表（_MyTicketsTab）、维修项目选择器（_ProjectSelector）、
// 新增地址入口 + 弹窗（_AddAddressButton / _AddAddressSheet）。
//
// ⚠️ 不要在此文件引入主 library 之外的新 import；依赖主文件已有的
// import（material / models / providers / theme_shape / widgets 等）。
part of 'repair_page.dart';

/// 我的报修工单列表（含状态显示）。
///
/// 持有 [ScrollController]：每次刷新（下拉/操作返回/点击刷新按钮）后
/// 列表都滚回顶端，确保用户能看到最新的工单状态。
class _MyTicketsTab extends StatefulWidget {
  const _MyTicketsTab({super.key, required this.provider});

  final ZhhqRepairProvider provider;

  @override
  State<_MyTicketsTab> createState() => _MyTicketsTabState();
}

class _MyTicketsTabState extends State<_MyTicketsTab> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ZhhqRepairProvider get provider => widget.provider;

  /// 刷新列表并滚回顶端。
  Future<void> _refresh() async {
    await provider.loadTickets(force: true);
    if (!_scrollController.hasClients) return;
    // 滚动动画无需等待完成即视为刷新结束（fire-and-forget）。
    unawaited(
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tickets = provider.tickets;
    // 首次加载中（列表为空且正在拉取）：显示加载指示，避免白屏
    if (tickets.isEmpty && provider.isLoadingTickets) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tickets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(
                l10n.noData,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: tickets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _buildTicket(context, l10n, tickets[index]),
      ),
    );
  }

  Widget _buildTicket(
    BuildContext context,
    AppLocalizations l10n,
    RepairTicket ticket,
  ) {
    return StyledCard(
      onTap: () => _openDetail(context, ticket),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.projectName.isEmpty
                        ? l10n.repairTicket
                        : ticket.projectName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (ticket.statusLabel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(
                        context,
                        ticket.status,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppShapes.small),
                    ),
                    child: Text(
                      ticket.statusLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _statusColor(context, ticket.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (ticket.areaName.isNotEmpty)
              Text(
                '${l10n.repairArea}: ${ticket.areaName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (ticket.serviceUnit.isNotEmpty)
              Text(
                ticket.serviceUnit,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (ticket.content.isNotEmpty)
              Text(
                ticket.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }

  /// 点击工单卡片进入详情页（支持撤回/评价操作）。
  ///
  /// 撤回/评价成功后用户留在详情页（详情实时刷新状态/按钮），
  /// 不 pop 返回列表，因此这里无需任何返回刷新链路；
  /// 列表展示最新状态交给：下拉刷新 / AppBar 刷新（均为 force）。
  void _openDetail(BuildContext context, RepairTicket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepairDetailPage(
          ticketId: ticket.id,
          initialTitle: ticket.projectName.isEmpty
              ? AppLocalizations.of(context)!.repairTicket
              : ticket.projectName,
          initialStatus: ticket.statusLabel,
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, String status) {
    // 后端动态接口直接返回中文状态
    if (status.contains('待') || status.contains('处理') || status.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }
    if (status.contains('评价')) {
      return Theme.of(context).colorScheme.tertiary;
    }
    if (status.contains('关闭')) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    if (status.contains('撤回')) {
      return Theme.of(context).colorScheme.error;
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

/// 维修项目选择器（按区域加载，两级：大类 → 具体项目）。
class _ProjectSelector extends StatefulWidget {
  const _ProjectSelector({
    required this.provider,
    required this.areaId,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final ZhhqRepairProvider provider;
  final String? areaId;
  final String? value;
  final String label;
  final void Function(String value, String label) onChanged;

  @override
  State<_ProjectSelector> createState() => _ProjectSelectorState();
}

class _ProjectSelectorState extends State<_ProjectSelector> {
  List<RepairProject> _categories = const [];
  RepairProject? _selectedCategory;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // 首次 build 时也加载（didUpdateWidget 只在 areaId 变化时触发）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProjects();
    });
  }

  @override
  void didUpdateWidget(covariant _ProjectSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.areaId != widget.areaId) {
      // 区域变化：清空已选类目，重新加载
      if (_selectedCategory != null || widget.value != null) {
        _selectedCategory = null;
        widget.onChanged('', '');
      }
      _loadProjects();
    }
  }

  Future<void> _loadProjects() async {
    final areaId = widget.areaId;
    if (areaId == null || areaId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final projects = await widget.provider.fetchProjects(areaId);
      if (mounted) setState(() => _categories = projects);
    } catch (_) {
      if (mounted) setState(() => _categories = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_categories.isEmpty) {
      return Text(
        l10n.repairSelectProjectHint,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final category = _selectedCategory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一级：大类
        DropdownButtonFormField<RepairProject>(
          initialValue: category,
          hint: Text(l10n.repairSelectCategory),
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: _categories
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(
                    c.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (c) {
            setState(() => _selectedCategory = c);
            // 已有已选叶子项目则交给用户重选
            if (widget.value != null && widget.value!.isNotEmpty) {
              widget.onChanged('', '');
            }
          },
        ),
        if (category != null) ...[
          const SizedBox(height: 8),
          // 第二级：具体项目
          if (category.children.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: widget.value,
              hint: Text(l10n.repairSelectProject),
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: category.children
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.value,
                      child: Text(
                        p.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                final label = category.children
                    .where((p) => p.value == v)
                    .map((p) => p.label)
                    .firstOrNull;
                // projectName 用「大类/项目」完整名（与前端提交一致）
                widget.onChanged(v ?? '', '$categoryLabel/$label');
              },
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.repairNoProjectInCategory,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }

  String get categoryLabel =>
      _selectedCategory?.label ??
      _categories
          .where((c) => c.children.any((p) => p.value == widget.value))
          .map((c) => c.label)
          .firstOrNull ??
      '';
}

/// 「新增地址」入口按钮 + 弹窗。
class _AddAddressButton extends StatelessWidget {
  const _AddAddressButton({required this.provider, required this.onSaved});

  final ZhhqRepairProvider provider;
  final VoidCallback onSaved;

  Future<void> _showAddDialog(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AddAddressSheet(provider: provider),
    );
    if (saved == true) onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextButton.icon(
      onPressed: () => _showAddDialog(context),
      icon: const Icon(Icons.add_location_alt_outlined, size: 18),
      label: Text(l10n.repairAddAddress),
    );
  }
}

/// 新增地址弹窗：区域树选择 + 详细地址 + 手机号。
class _AddAddressSheet extends StatefulWidget {
  const _AddAddressSheet({required this.provider});

  final ZhhqRepairProvider provider;

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _detailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();

  List<RepairAreaNode> _areaTree = const [];
  bool _loadingTree = true;
  String? _selectedAreaId;
  String _selectedAreaName = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAreaTree();
  }

  @override
  void dispose() {
    _detailController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadAreaTree() async {
    try {
      final tree = await widget.provider.fetchAreaTree();
      if (mounted) setState(() => _areaTree = tree);
    } catch (_) {
      // 失败时保持空树
    } finally {
      if (mounted) setState(() => _loadingTree = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedAreaId == null || _selectedAreaName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.repairSelectArea),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final success = await widget.provider.addAddress(
      areaId: _selectedAreaId!,
      areaName: _selectedAreaName,
      addressDetail: _detailController.text.trim(),
      phone: _phoneController.text.trim(),
      userName: _nameController.text.trim(),
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.repairAddressSaved),
        ),
      );
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.provider.submitError ??
                AppLocalizations.of(context)!.repairSubmitFailed,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.repairAddAddress,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (_loadingTree)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2))
                else ...[
                  DropdownButtonFormField<RepairAreaNode>(
                    initialValue: _areaTree
                        .where((n) => n.id == _selectedAreaId)
                        .firstOrNull,
                    hint: Text(l10n.repairSelectArea),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.repairAddress,
                      border: const OutlineInputBorder(),
                    ),
                    items: _areaTree
                        .expand(
                          (n) => [
                            DropdownMenuItem(value: n, child: Text(n.name)),
                            ...n.children.map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 24),
                                  child: Text(
                                    '${n.name} / ${c.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedAreaId = v?.id;
                      _selectedAreaName = v == null ? '' : v.fullName;
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _detailController,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: l10n.repairAddressDetail,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.repairAddressDetailRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.nameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.phoneLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final phone = (v ?? '').trim();
                    if (phone.isEmpty) return l10n.repairPhoneRequired;
                    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
                      return l10n.repairPhoneInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.confirm),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
