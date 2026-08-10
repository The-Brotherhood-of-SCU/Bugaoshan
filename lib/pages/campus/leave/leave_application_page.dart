import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/service_api_service.dart';
import 'package:bugaoshan/services/api/service_form_fields.dart';
import 'package:bugaoshan/services/api/service_form_models.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/service_auth.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/service_region_picker.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 请假申请页面（办事大厅原生嵌入，app_id=350 离校请假）
///
/// 字段结构来自真实表单（`/site/form/start-data`）：
/// - Radio_30 离开校区（必填）
/// - Radio_67 请假事由（必填）
/// - MultiInput_40 其他事由（仅当请假事由选择"其它"时显示）
/// - Calendar_25 / Calendar_26 日期（必填）
/// - Region_80 去往地址（必填）
/// - File_71 上传证明（可选，1-3 张图片）
/// - User_21~24 学号/姓名/学院/手机号（服务端带出，只读）
///
/// 认证复用 [ServiceAuth] 建立的办事大厅 CAS 会话，不弹网页登录。
class LeaveApplicationPage extends StatefulWidget {
  const LeaveApplicationPage({super.key});

  @override
  State<LeaveApplicationPage> createState() => _LeaveApplicationPageState();
}

class _LeaveApplicationPageState extends State<LeaveApplicationPage> {
  final _detailController = TextEditingController();

  // Radio_30 离开校区（value 对应 1/2/3）
  String? _campusValue;
  // Radio_67 请假事由（value 对应 1~7）
  String? _reasonValue;
  // Calendar_25 / Calendar_26 日期
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));

  bool _submitting = false;

  /// 已选附件（本地文件）。提交时逐个上传并组装 File_71。
  final List<File> _attachments = [];

  /// 登录后从办事大厅加载的表单定义（含服务端带出的个人信息）。
  ServiceFormDefinition? _formDef;

  /// 辅导员姓名（DataSource_85 数据源），加载表单时一并获取，展示在学生信息卡。
  String? _tutorName;

  /// 省市区数据（在线加载，来自办事大厅 region 接口）。
  List<ServiceRegionNode> _regions = const [];
  bool _regionsLoading = false;
  /// 已选地区（Region_80）。
  ServiceRegionSelection? _region;

  @override
  void initState() {
    super.initState();
    getIt<ScuAuthProvider>().addListener(_onAuthChanged);
    getIt<ServiceAuth>().addListener(_onServiceAuthChanged);
    // 省市区数据来自本地 asset，无需登录即可加载。
    unawaited(_loadRegions());
    if (getIt<ScuAuthProvider>().isLoggedIn) {
      unawaited(_loadFormDefinition());
    }
  }

  @override
  void dispose() {
    getIt<ScuAuthProvider>().removeListener(_onAuthChanged);
    getIt<ServiceAuth>().removeListener(_onServiceAuthChanged);
    _detailController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (getIt<ScuAuthProvider>().isLoggedIn) {
      unawaited(_loadFormDefinition());
    }
    if (mounted) setState(() {});
  }

  void _onServiceAuthChanged() {
    if (getIt<ServiceAuth>().isReady) {
      // SSO 就绪后加载表单定义（可能 initState 时还没就绪，导致学生信息空白）
      if (_formDef == null) unawaited(_loadFormDefinition());
    }
    if (mounted) setState(() {});
  }

  bool _formDefLoading = false;
  bool _formDefFailed = false;

  /// 加载表单定义。接口未就绪或认证未完成时静默忽略，信息卡显示占位，
  /// 不打断用户填表。失败时记录状态，由 UI 提供重试入口。
  Future<void> _loadFormDefinition() async {
    if (!getIt<ScuAuthProvider>().isLoggedIn) return;
    if (_formDefLoading) return;
    setState(() {
      _formDefLoading = true;
      _formDefFailed = false;
    });
    try {
      final def = await getIt<ServiceApiService>().fetchLeaveFormSchema();
      if (!mounted) return;
      setState(() => _formDef = def);
      // 表单加载成功后一并获取辅导员（用于学生信息卡展示）。
      // 失败不影响主流程，静默忽略。
      unawaited(_loadTutor());
    } catch (e) {
      debugPrint('Leave form def load skipped: $e');
      if (mounted) setState(() => _formDefFailed = true);
    } finally {
      if (mounted) setState(() => _formDefLoading = false);
    }
  }

  /// 获取辅导员姓名（DataSource_85 数据源），用于学生信息卡展示。
  Future<void> _loadTutor() async {
    try {
      final tutor = await getIt<ServiceApiService>().fetchTutor();
      if (!mounted) return;
      setState(() => _tutorName = tutor);
    } catch (e) {
      debugPrint('Leave tutor load skipped: $e');
    }
  }

  /// 从本地 asset 加载省市区数据（Region_80 三级联动，无需在线接口）。
  Future<void> _loadRegions() async {
    if (_regions.isNotEmpty || _regionsLoading) return;
    setState(() => _regionsLoading = true);
    try {
      // 优先从办事大厅在线接口拉取省市区；失败回退本地 asset。
      List<dynamic> data;
      try {
        if (!getIt<ScuAuthProvider>().isLoggedIn) {
          throw StateError('not logged in');
        }
        data = await getIt<ServiceApiService>().fetchProvinces();
        if (data.isEmpty) throw StateError('empty provinces');
      } catch (e) {
        debugPrint('Leave region online load failed, fallback to asset: $e');
        final raw = await rootBundle.loadString('assets/region_data.json');
        data = jsonDecode(raw) as List;
      }
      if (mounted) {
        setState(() {
          _regions = data
              .map(
                (e) => ServiceRegionNode.fromJson(e as Map<String, dynamic>),
              )
              .toList(growable: false);
        });
      }
    } catch (e) {
      debugPrint('Leave region load skipped: $e');
    } finally {
      if (mounted) setState(() => _regionsLoading = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = date;
      } else {
        _endDate = date;
      }
    });
  }

  /// 把单选 value 组装成办事大厅的 {value, name} 结构。
  Map<String, dynamic>? _radioValue(
    String? value,
    ServiceFieldMeta meta,
  ) {
    if (value == null) return null;
    final name = meta.options?.firstWhere(
          (o) => o.value == value,
          orElse: () => ServiceFieldOption(value, ''),
        ).label ??
        '';
    return {'value': value, 'name': name};
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_campusValue == null) {
      _showSnack(l10n.leaveCampusRequired);
      return;
    }
    if (_reasonValue == null) {
      _showSnack(l10n.leaveReasonRequired);
      return;
    }
    if (_region == null || _region!.isEmpty) {
      _showSnack(l10n.leaveRegionRequired);
      return;
    }
    if (!_endDate.isAfter(_startDate)) {
      _showSnack(l10n.leaveEndAfterStart);
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = getIt<ServiceApiService>();
      // 从 start-data 加载的表单定义中取自动带出的字段（学号/姓名/学院/手机号等）
      final formId = _formDef?.currform.isNotEmpty == true
          ? _formDef!.currform.first.toString()
          : '1419';
      final autoData = _formDef?.data ?? {};

      // 获取辅导员（DataSource_85 数据源），填入 Input_84 / DataSource_85。
      // 优先复用学生信息卡已加载的 _tutorName；未加载到则现场获取。
      // 失败不阻塞提交（部分事项/账号可能无辅导员字段）。
      final tutor = _tutorName ?? await api.fetchTutor();

      // 逐个上传附件，组装 File_71（上传失败则抛错中断提交）。
      final attachments = <Map<String, dynamic>>[];
      for (final file in _attachments) {
        final uploaded = await api.uploadAttachment(file);
        attachments.add(uploaded.toFormData());
      }

      // 组装 form_data：键为表单 id（如 1419），值是该表单的完整字段 Map
      final formFields = <String, dynamic>{
        ...autoData, // 学号/姓名/学院/手机号等（服务端带出）
        // 自动带出的只读/数据源字段（若有）
        'File_71': attachments,
        'Variate_75': '',
        'ShowHide_44': '',
        'ShowHide_83': '',
        'Validate_86': '',
        'Conversion_74': const [],
        'RepeatTable_76': const [],
        if (tutor != null && tutor.isNotEmpty) ...{
          'Input_84': tutor, // 辅导员姓名（front_readonly，网页端由数据源带出）
          'DataSource_85': {'list': tutor}, // 辅导员数据源
        },
        'Radio_30': _radioValue(
          _campusValue,
          ServiceFormFields.radioCampus,
        ), // {"value":"3","name":"江安校区"}
        'Radio_67': _radioValue(
          _reasonValue,
          ServiceFormFields.radioReason,
        ), // {"value":"1","name":"实习"}
        kFieldLeaveDate: _startDate.toUtc().toIso8601String(),
        kFieldReturnDate: _endDate.toUtc().toIso8601String(),
        kFieldRegion: _region!.toRegionData(),
        // 其他事由仅在请假事由选择"其它"时填写
        kFieldDetail: _reasonValue == '7' ? _detailController.text.trim() : '',
      };

      await api.submitLeave({formId: formFields});
      if (!mounted) return;
      _showSnack(l10n.leaveSubmitSuccess);
      _campusValue = null;
      _reasonValue = null;
      _detailController.clear();
      _attachments.clear();
    } on UnauthenticatedException {
      if (mounted) _showSnack(l10n.loginRequired, isError: true);
    } catch (e) {
      debugPrint('Leave submit error: $e');
      if (mounted) _showSnack(l10n.leaveSubmitFailed, isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaveTitle)),
      body: _buildApplyTab(l10n),
    );
  }

  Widget _buildApplyTab(AppLocalizations l10n) {
    if (!getIt<ScuAuthProvider>().isLoggedIn) {
      return const LoginRequiredWidget();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(l10n),
        const SizedBox(height: 12),
        _buildCampusCard(l10n),
        const SizedBox(height: 12),
        _buildReasonCard(l10n),
        // 其他事由输入框：仅当请假事由选择"其它"(7)时显示
        if (_reasonValue == '7') ...[
          const SizedBox(height: 12),
          _buildDetailCard(l10n),
        ],
        const SizedBox(height: 12),
        _buildDateCard(l10n),
        const SizedBox(height: 12),
        _buildRegionCard(l10n),
        const SizedBox(height: 12),
        _buildAttachmentCard(l10n),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(l10n.leaveSubmit),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  /// 服务端带出的只读信息（学号/姓名/学院/手机号）。
  Widget _buildInfoCard(AppLocalizations l10n) {
    return CardWithTitle(
      title: l10n.leaveInfo,
      icon: const Icon(Icons.badge_outlined),
      child: Column(
        children: [
          if (_formDefLoading && _formDef == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_formDefFailed && _formDef == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.loadFailed,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadFormDefinition,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            )
          else ...[
            for (final f in ServiceFormFields.readonlyInfo)
              _readonlyRow(f, l10n),
            // 辅导员行（来自 DataSource_85 数据源；未加载到则显示占位）
            _readonlyRow(
              ServiceFieldMeta(
                key: 'tutor',
                label: l10n.leaveTutor,
                icon: Icons.support_agent_outlined,
              ),
              l10n,
            ),
          ],
        ],
      ),
    );
  }

  Widget _readonlyRow(ServiceFieldMeta f, AppLocalizations l10n) {
    // 辅导员行取 _tutorName（数据源接口）；其余行取表单 data。
    final raw = f.key == 'tutor' ? _tutorName : _formDef?.data[f.key];
    final value = raw == null ? '' : raw.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(f.icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              f.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// 离开校区单选（Radio_30）。
  Widget _buildCampusCard(AppLocalizations l10n) {
    return CardWithTitle(
      title: ServiceFormFields.radioCampus.label,
      icon: Icon(ServiceFormFields.radioCampus.icon),
      child: RadioGroup<String>(
        groupValue: _campusValue,
        onChanged: (v) => setState(() => _campusValue = v),
        child: Column(
          children: [
            for (final opt in ServiceFormFields.radioCampus.options!)
              RadioListTile<String>(
                value: opt.value,
                title: Text(opt.label),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  /// 请假事由单选（Radio_67）。
  Widget _buildReasonCard(AppLocalizations l10n) {
    return CardWithTitle(
      title: ServiceFormFields.radioReason.label,
      icon: Icon(ServiceFormFields.radioReason.icon),
      child: RadioGroup<String>(
        groupValue: _reasonValue,
        onChanged: (v) => setState(() => _reasonValue = v),
        child: Column(
          children: [
            for (final opt in ServiceFormFields.radioReason.options!)
              RadioListTile<String>(
                value: opt.value,
                title: Text(opt.label),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  /// 日期区间（Calendar_25 离校时间 / Calendar_26 返校时间）。
  Widget _buildDateCard(AppLocalizations l10n) {
    String fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    return CardWithTitle(
      title: l10n.leaveDepartReturn,
      icon: const Icon(Icons.schedule_outlined),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.leaveDepartTime),
            subtitle: Text(fmt(_startDate)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickDate(isStart: true),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            leading: const Icon(Icons.login),
            title: Text(l10n.leaveReturnTime),
            subtitle: Text(fmt(_endDate)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickDate(isStart: false),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  /// 去往地址（Region_80，省-市-区县三级 + 详细地址，必填）。
  Widget _buildRegionCard(AppLocalizations l10n) {
    return CardWithTitle(
      title: ServiceFormFields.region.label,
      icon: Icon(ServiceFormFields.region.icon),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_regionsLoading && _regions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_regions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                ServiceFormFields.region.hint!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ServiceRegionPicker(
              provinces: _regions,
              initial: _region,
              labels: ServiceRegionLabels(
                province: l10n.regionProvince,
                city: l10n.regionCity,
                area: l10n.regionArea,
                selectHint: l10n.regionSelectHint,
                detailHint: l10n.regionDetailHint,
                pickProvince: l10n.regionPickProvince,
                pickCity: l10n.regionPickCity,
                pickArea: l10n.regionPickArea,
              ),
              onChanged: (sel) => setState(() => _region = sel),
            ),
        ],
      ),
    );
  }

  /// 其他事由输入框（MultiInput_40）。仅当请假事由选择"其它"(7)时显示，
  /// 用于补充具体事由。
  Widget _buildDetailCard(AppLocalizations l10n) {
    return CardWithTitle(
      title: l10n.leaveDetail,
      icon: const Icon(Icons.edit_note_outlined),
      child: TextField(
        controller: _detailController,
        maxLines: 3,
        maxLength: 500,
        decoration: InputDecoration(
          hintText: l10n.leaveDetailHint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  /// 上传证明卡片（File_71，可选，最多 3 张）。
  Widget _buildAttachmentCard(AppLocalizations l10n) {
    return CardWithTitle(
      title: l10n.leaveAttachment,
      icon: const Icon(Icons.attach_file_outlined),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_attachments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                l10n.leaveAttachmentHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _attachments.length; i++)
                  _attachmentThumb(i),
                if (_attachments.length < 3)
                  _addAttachmentTile(),
              ],
            ),
          if (_attachments.isEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(l10n.leaveAttachmentAdd),
              ),
            ),
        ],
      ),
    );
  }

  Widget _attachmentThumb(int index) {
    final file = _attachments[index];
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: () => setState(() => _attachments.removeAt(index)),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addAttachmentTile() {
    return InkWell(
      onTap: _pickAttachment,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _pickAttachment() async {
    if (_attachments.length >= 3) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    if (!await file.exists()) return;
    setState(() => _attachments.add(file));
  }

}
