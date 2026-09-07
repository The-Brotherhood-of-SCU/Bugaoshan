// 本文件是 `repair_page.dart` 的 part：报修提交表单（最大的子 widget）。
//
// ⚠️ 不要在此文件引入主 library 之外的新 import；依赖主文件已有的
// import（material / models / providers / theme_shape 等）。
part of 'repair_page.dart';

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
  ///
  /// 注意：Provider 刷新（如提交成功后的 `refresh()`）会用**新对象**替换地址列表，
  /// 必须按 id 把 `_selectedAddress` 重新同步为列表中的实例，否则
  /// `DropdownButtonFormField` 的 value 会指向列表外的旧对象 → 断言崩溃。
  /// （`DropdownButtonFormField` 在 `initialValue` 引用变化时才会 `setValue` 同步
  /// 内部值，所以即使 id 相同也要换用列表中的新实例，不能保留旧引用。）
  void _ensureDefaultAddress() {
    final addresses = widget.provider.addresses;
    if (addresses.isEmpty) {
      if (_selectedAddress != null) _selectedAddress = null;
      return;
    }
    if (_selectedAddress != null) {
      // 在刷新后的列表中找同 id 的新实例
      final matched = addresses
          .where((a) => a.id == _selectedAddress!.id)
          .firstOrNull;
      if (matched != null) {
        _selectedAddress = matched;
      } else {
        // 原地址已被删除：重置，走默认选择逻辑；项目跟随地址清空，让用户重选
        _selectedAddress = null;
        if (_projectValue != null && _projectValue!.isNotEmpty) {
          _projectValue = null;
          _projectLabel = '';
        }
      }
    }
    if (_selectedAddress != null) return;
    final common = addresses.where((a) => a.isCommon).firstOrNull;
    _selectedAddress = common ?? addresses.first;
  }

  /// 图片格式白名单（与 zhhq 上传接口支持的格式一致）。
  static const _allowedImageExts = {'jpg', 'jpeg', 'png', 'heic', 'heif'};

  /// 单张图片大小上限（10MB，防止超大图上传慢 / OOM）。
  static const _maxImageBytes = 10 * 1024 * 1024;

  Future<void> _pickImages() async {
    if (_images.length >= 3) return;
    final l10n = AppLocalizations.of(context)!;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    if (!await file.exists()) return;
    // 类型校验：仅允许常见图片格式，避免误选其他文件类型
    final ext = picked.path.split('.').last.toLowerCase();
    if (!_allowedImageExts.contains(ext)) {
      _showError(l10n.repairImageTypeInvalid);
      return;
    }
    // 大小校验：超过上限直接拒绝
    final size = await file.length();
    if (size > _maxImageBytes) {
      _showError(l10n.repairImageTooLarge);
      return;
    }
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

    // 提交时统一上传图片 + 预取维修部门，全部成功后才发送工单。
    // _uploadingImages 贯穿整个提交链（上传/预取/publish），期间按钮禁用防重复提交。
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

    // 预取维修负责部门（acceptDeptId/acceptDeptName/payName 来源）
    final dept = await widget.provider.fetchAcceptDept(
      areaId: _selectedAddress!.areaId,
      projectId: _projectValue!,
    );
    if (!mounted) return;
    setState(() => _uploadingImages = false);

    final payload = <String, dynamic>{
      // 与前端提交链完全一致（缺字段服务端会报"缺少参数"）
      'type': '0',
      'ifShielding': '1',
      'areaName': _selectedAddress!.areaName,
      'address': _selectedAddress!.addressDetail,
      'projectName': _projectLabel,
      'bookDate': _bookDate ?? '',
      'bookTime': _bookTime ?? '',
      'repairUserName': getIt<ScuAuthProvider>().userRealname ?? '',
      'repairUserMobile': _selectedAddress!.phone,
      'repairDeptName': '',
      'ifOnduty': _allowNoOneRepair ? '1' : '0',
      'repairNum': 1,
      'content': _contentController.text.trim(),
      'ifPublish': '1',
      'ifUrgent': '0',
      'id': '',
      'resourcesVOS': resources,
      'source': '1',
      'projectId': _projectValue,
      'areaId': _selectedAddress!.areaId,
      if (dept != null) ...{
        'payName': dept.payName,
        'acceptDeptId': dept.deptId,
        'acceptDeptName': dept.deptName,
      },
      'ifRecord': 0,
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
              provider: widget.provider,
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
    final dates = await widget.provider.fetchBookDates();
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
    final times = await widget.provider.fetchBookTimes(_bookDate!);
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
}
