import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/repair.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/zhhq_repair_provider.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';

/// 智慧后勤在线报修页。
///
/// 对接 zhhq（智慧后勤）平台的报修服务：选择地址/维修项目、填写故障描述、
/// 上传现场照片、预约时间后提交工单，并可查看我的报修列表。
///
/// 认证通过 [ZhhqAuth]（走 SCU 统一身份认证 SSO 换取 zhhq tokenKey），
/// 与 passpoint/办事大厅同为原生 HTTP 实现。
class RepairPage extends StatefulWidget {
  const RepairPage({super.key});

  @override
  State<RepairPage> createState() => _RepairPageState();
}

class _RepairPageState extends State<RepairPage> {
  @override
  Widget build(BuildContext context) {
    final auth = getIt<ScuAuthProvider>();
    final provider = getIt<ZhhqRepairProvider>();

    return ListenableBuilder(
      listenable: Listenable.merge([auth, provider]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.repairTitle),
              bottom: TabBar(
                tabs: [
                  Tab(text: l10n.repairTabSubmit),
                  Tab(text: l10n.repairTabMyTickets),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: provider.state == RepairLoadState.loading
                      ? null
                      : provider.refresh,
                  tooltip: l10n.refresh,
                ),
              ],
            ),
            body: _buildBody(l10n, auth, provider),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    ScuAuthProvider auth,
    ZhhqRepairProvider provider,
  ) {
    if (!auth.isLoggedIn) {
      return auth.isAutoLoggingIn
          ? const AutoLoginLoadingWidget()
          : const LoginRequiredWidget();
    }

    final hasData = provider.addresses.isNotEmpty;
    if (provider.state == RepairLoadState.idle ||
        (provider.state == RepairLoadState.loading && !hasData)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.state == RepairLoadState.error && !hasData) {
      return RetryableErrorWidget(
        errorType: provider.error ?? LoadErrorType.networkError,
        onRetry: () {
          // 认证失败时重新走认证；否则直接刷新地址
          if (auth.isLoggedIn && !provider.isReadyForRequest) {
            provider.retryAuth();
          } else {
            provider.refresh();
          }
        },
      );
    }

    // 异步加载工单列表（不阻塞地址展示；myList 服务端慢，独立处理）
    unawaited(provider.loadTickets());

    return TabBarView(
      children: [
        _SubmitTab(provider: provider),
        _MyTicketsTab(provider: provider),
      ],
    );
  }
}

/// 我的报修工单列表（含状态显示）。
class _MyTicketsTab extends StatelessWidget {
  const _MyTicketsTab({required this.provider});

  final ZhhqRepairProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tickets = provider.tickets;
    if (tickets.isEmpty && !provider.isLoadingTickets) {
      return RefreshIndicator(
        onRefresh: provider.loadTickets,
        child: ListView(
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
      onRefresh: provider.loadTickets,
      child: ListView.separated(
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

/// 提交报修表单。
class _SubmitTab extends StatefulWidget {
  const _SubmitTab({required this.provider});

  final ZhhqRepairProvider provider;

  @override
  State<_SubmitTab> createState() => _SubmitTabState();
}

class _SubmitTabState extends State<_SubmitTab> {
  RepairAddress? _selectedAddress;
  String? _projectValue;
  String _projectLabel = '';
  final _contentController = TextEditingController();
  final List<File> _images = [];
  bool _uploadingImages = false;
  bool _allowNoOneRepair = true;
  String? _bookDate;
  String? _bookTime;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// 地址加载后自动选中默认地址（isCommon），无默认则选第一个。
  /// 在 build 前调用，保证 `_selectedAddress` 非空以便项目栏加载。
  void _ensureDefaultAddress() {
    if (_selectedAddress != null) return;
    final addresses = widget.provider.addresses;
    if (addresses.isEmpty) return;
    final common = addresses.where((a) => a.isCommon).firstOrNull;
    _selectedAddress = common ?? addresses.first;
  }

  Future<void> _pickImages() async {
    if (_images.length >= 3) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    if (!await file.exists()) return;
    setState(() => _images.add(file));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedAddress == null) {
      _showError(l10n.repairSelectAddress);
      return;
    }
    if (_projectValue == null || _projectValue!.isEmpty) {
      _showError(l10n.repairSelectProject);
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      _showError(l10n.repairContentRequired);
      return;
    }

    // 提交时统一上传图片，全部成功后才发送工单
    setState(() => _uploadingImages = true);
    final resources = <Map<String, String>>[];
    try {
      for (final file in _images) {
        final path = await widget.provider.uploadImage(file: file);
        resources.add({'fileUrl': path, 'fileType': '1', 'statusType': '1'});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingImages = false);
      _showError(e.toString());
      return;
    }
    if (!mounted) return;
    setState(() => _uploadingImages = false);

    final payload = <String, dynamic>{
      'areaId': _selectedAddress!.areaId,
      'address': _selectedAddress!.displayName,
      'repairUserAddressId': _selectedAddress!.id,
      'projectId': _projectValue,
      'projectName': _projectLabel,
      'content': _contentController.text.trim(),
      'repairUserMobile': _selectedAddress!.phone,
      'ifOnduty': _allowNoOneRepair ? '1' : '0',
      'ifPublish': '1',
      'ifUrgent': '0',
      'source': '1',
      'repairNum': 1,
      'repairDeptName': '',
      'resourcesVOS': resources,
      if (_bookDate != null) 'bookDate': _bookDate,
      if (_bookTime != null) 'bookTime': _bookTime,
    };

    final success = await widget.provider.submitTicket(payload);
    if (!mounted) return;
    if (success) {
      _contentController.clear();
      setState(() {
        _images.clear();
        _bookDate = null;
        _bookTime = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.repairSubmitSuccess)));
    } else {
      _showError(widget.provider.submitError ?? l10n.repairSubmitFailed);
    }
  }

  void _showError(String message) {
    // 在调用前已捕获 messenger/colorScheme，避免 async gap 后访问 context。
    _messenger?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _errorColor),
    );
  }

  ScaffoldMessengerState? _messenger;
  Color? _errorColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _ensureDefaultAddress();
    // 缓存 messenger 与错误色，供异步操作后展示 SnackBar（避免 async gap 访问 context）。
    _messenger = ScaffoldMessenger.of(context);
    _errorColor = Theme.of(context).colorScheme.error;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardWithTitle(
          title: l10n.repairAddress,
          icon: const Icon(Icons.location_on_outlined),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: widget.provider.addresses.isEmpty
                ? Column(
                    children: [
                      Text(
                        l10n.noData,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      _AddAddressButton(
                        provider: widget.provider,
                        onSaved: () {
                          // 保存成功后默认选中第一个地址
                          setState(() => _selectedAddress = null);
                        },
                      ),
                    ],
                  )
                : Column(
                    children: [
                      DropdownButtonFormField<RepairAddress>(
                        initialValue: _selectedAddress,
                        isDense: true,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: widget.provider.addresses
                            .map(
                              (a) => DropdownMenuItem(
                                value: a,
                                child: Text(
                                  a.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedAddress = v),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _AddAddressButton(
                          provider: widget.provider,
                          onSaved: () {
                            // 保存成功后重置选中，让默认地址逻辑重新生效
                            setState(() => _selectedAddress = null);
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        CardWithTitle(
          title: l10n.repairProject,
          icon: const Icon(Icons.build_outlined),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _ProjectSelector(
              areaId: _selectedAddress?.areaId,
              value: _projectValue,
              label: _projectLabel,
              onChanged: (value, label) => setState(() {
                _projectValue = value;
                _projectLabel = label;
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        CardWithTitle(
          title: l10n.repairContent,
          icon: const Icon(Icons.description_outlined),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _contentController,
              maxLength: 200,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: l10n.repairContentHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        CardWithTitle(
          title: l10n.repairPhotos,
          icon: const Icon(Icons.photo_library_outlined),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _images.length; i++) _imageThumb(i),
                    if (_images.length < 3)
                      InkWell(
                        onTap: _pickImages,
                        borderRadius: BorderRadius.circular(AppShapes.small),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppShapes.small,
                            ),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: const Icon(Icons.add_a_photo_outlined),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_images.length} / 3',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        CardWithTitle(
          title: l10n.repairSchedule,
          icon: const Icon(Icons.schedule_outlined),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.repairAllowNoOne),
                  value: _allowNoOneRepair,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _allowNoOneRepair = v),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.repairBookDate),
                  trailing: Text(_bookDate ?? l10n.repairNotSelected),
                  onTap: () => _showBookDatePicker(),
                ),
                if (_bookDate != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.repairBookTime),
                    trailing: Text(_bookTime ?? l10n.repairNotSelected),
                    onTap: () => _showBookTimePicker(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.provider.isSubmitting || _uploadingImages
                ? null
                : _submit,
            icon: widget.provider.isSubmitting || _uploadingImages
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              _uploadingImages ? l10n.repairImageUploading : l10n.repairSubmit,
            ),
          ),
        ),
      ],
    );
  }

  Widget _imageThumb(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppShapes.small),
          child: Image.file(
            _images[index],
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => setState(() => _images.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showBookDatePicker() async {
    final l10n = AppLocalizations.of(context)!;
    final dates = await _fetchBookDates();
    if (!mounted) return;
    if (dates.isEmpty) {
      _showError(l10n.repairNoBookDate);
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.repairBookDate),
        children: dates
            .map(
              (d) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, d),
                child: Text(d),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _bookDate = selected;
        _bookTime = null;
      });
    }
  }

  Future<void> _showBookTimePicker() async {
    final l10n = AppLocalizations.of(context)!;
    if (_bookDate == null) return;
    final times = await _fetchBookTimes(_bookDate!);
    if (!mounted) return;
    if (times.isEmpty) {
      _showError(l10n.repairNoBookTime);
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.repairBookTime),
        children: times
            .map(
              (t) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, t),
                child: Text(t),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _bookTime = selected);
    }
  }

  Future<List<String>> _fetchBookDates() async {
    return widget.provider.fetchBookDates();
  }

  Future<List<String>> _fetchBookTimes(String date) async {
    return widget.provider.fetchBookTimes(date);
  }
}

/// 维修项目选择器（按区域加载，支持搜索）。
class _ProjectSelector extends StatefulWidget {
  const _ProjectSelector({
    required this.areaId,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final String? areaId;
  final String? value;
  final String label;
  final void Function(String value, String label) onChanged;

  @override
  State<_ProjectSelector> createState() => _ProjectSelectorState();
}

class _ProjectSelectorState extends State<_ProjectSelector> {
  List<RepairProject> _projects = const [];
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
      _loadProjects();
    }
  }

  Future<void> _loadProjects() async {
    final areaId = widget.areaId;
    if (areaId == null || areaId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final projects = await getIt<ZhhqRepairProvider>().fetchProjects(areaId);
      if (mounted) setState(() => _projects = projects);
    } catch (_) {
      if (mounted) setState(() => _projects = const []);
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
    if (_projects.isEmpty) {
      return Text(
        l10n.repairSelectProjectHint,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: widget.value,
      hint: Text(l10n.repairSelectProject),
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: _projects
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
        final label = _projects
            .where((p) => p.value == v)
            .map((p) => p.label)
            .firstOrNull;
        widget.onChanged(v ?? '', label ?? '');
      },
    );
  }
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
