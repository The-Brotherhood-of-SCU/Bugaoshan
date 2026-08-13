/// 办事大厅事项目录与每事项覆盖配置。
///
/// [kServiceAppCatalog] 静态列出可办理事项（appId + 图标 + 文案 + overrides），
/// 驱动 [ServiceHallPage] 列表与 [ServiceFormPage] 通用表单页。
///
/// 条件显示、动态必填、DataSource 配对、日期校验均由服务端插件配置驱动
/// （ShowHide/DataSource resultKey/Validate，已抓包确认）；[kApp350Overrides]
/// 只保留服务端表达不了的部分：
/// - 字段顺序：350 的 sort 值异常（Calendar_25=2/Calendar_26=3），用
///   fieldOrder 固定为已验证页面的顺序；
/// - 附加校验：返校时间必须晚于离校时间（350 服务端没有对应 Validate 规则）。
///
/// [buildLeaveFallbackSchema] 在实时表单定义拉取/解析失败时，用硬编码元数据
/// （`ServiceFormFields`，均已抓包验证）组装等价 schema，保证 350 这一唯一
/// 已验证流程绝不退化。
library;

import 'package:material_ui/material_ui.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/api/service_api_service.dart';
import 'package:bugaoshan/services/api/service_form_fields.dart';
import 'package:bugaoshan/services/api/service_form_models.dart';
import 'package:bugaoshan/services/api/service_plugin_models.dart';
import 'package:bugaoshan/pages/campus/service_hall/service_form_controller.dart';

/// 单个事项（办事大厅列表项）。
class ServiceAppInfo {
  /// 事项 id（如 '350'）。
  final String appId;

  /// 列表图标。
  final IconData icon;

  /// 事项名称（l10n）。
  final String Function(AppLocalizations) title;

  /// 事项描述（l10n）。
  final String Function(AppLocalizations) desc;

  /// 每事项覆盖配置。
  final ServiceAppOverrides overrides;

  /// start-info 拉取/解析失败时的硬编码 fallback schema 构建器。
  /// 仅 350 提供（唯一已抓包验证的事项）；其他事项为 null ——
  /// schema 不可用时失败封闭（错误 + 重试），绝不渲染猜测的表单。
  final ServiceFormSchema Function(ServiceFormDefinition startData)?
  fallbackSchema;

  const ServiceAppInfo({
    required this.appId,
    required this.icon,
    required this.title,
    required this.desc,
    this.overrides = const ServiceAppOverrides(),
    this.fallbackSchema,
  });
}

/// 350（离校请假）的覆盖配置（显隐/DataSource 配对已由服务端
/// ShowHide_44 / DataSource_85.resultKey 驱动，无需重复声明）。
final kApp350Overrides = ServiceAppOverrides(
  fieldOrder: const [
    'Radio_30', // 离开校区
    'Radio_67', // 事由
    kFieldDetail, // 其他事由（条件显示）
    kFieldLeaveDate, // 离校时间
    kFieldReturnDate, // 返校时间
    kFieldRegion, // 目的地
    'File_71', // 上传证明
  ],
  extraValidators: [_leaveDateOrderValidator],
);

/// 返校时间（Calendar_26）必须晚于离校时间（Calendar_25）。
ServiceValidationIssue? _leaveDateOrderValidator(ServiceFormController c) {
  final start = c.values[kFieldLeaveDate];
  final end = c.values[kFieldReturnDate];
  if (start is DateTime && end is DateTime && !end.isAfter(start)) {
    return const ServiceValidationIssue(
      kFieldReturnDate,
      ServiceValidationKind.custom,
      message: '返校时间必须晚于离校时间',
    );
  }
  return null;
}

/// 用硬编码元数据组装 350 的 fallback schema（实时定义失败时兜底，
/// 产出与已抓包验证的提交体逐字段相同的结构）。
ServiceFormSchema buildLeaveFallbackSchema(ServiceFormDefinition startData) {
  final formId = startData.currform.isNotEmpty
      ? startData.currform.first.toString()
      : '1419';
  const formVersionId = '2357';

  ServiceFormPlugin plugin(
    String key,
    ServiceFieldType type, {
    String label = '',
    int sort = 0,
    List<ServiceFieldOption> options = const [],
    ServiceDataSourceRef? dataSource,
  }) => ServiceFormPlugin(
    key: key,
    type: type,
    label: label,
    sort: sort,
    options: options,
    dataSource: dataSource,
  );

  return ServiceFormSchema(
    appId: ServiceApiService.leaveAppId,
    formId: formId,
    formVersionId: formVersionId,
    auth: startData.auth,
    data: startData.data,
    plugins: [
      // 只读信息（User_21~24 学号/姓名/学院/手机号）
      for (var i = 0; i < ServiceFormFields.readonlyInfo.length; i++)
        plugin(
          ServiceFormFields.readonlyInfo[i].key,
          ServiceFieldType.user,
          label: ServiceFormFields.readonlyInfo[i].label,
          sort: i + 1,
        ),
      plugin(
        'Radio_30',
        ServiceFieldType.radio,
        label: ServiceFormFields.radioCampus.label,
        sort: 10,
        options: ServiceFormFields.radioCampus.options ?? const [],
      ),
      plugin(
        'Radio_67',
        ServiceFieldType.radio,
        label: ServiceFormFields.radioReason.label,
        sort: 20,
        options: ServiceFormFields.radioReason.options ?? const [],
      ),
      plugin(
        kFieldDetail,
        ServiceFieldType.multiInput,
        label: '其他事由',
        sort: 30,
      ),
      plugin(
        kFieldLeaveDate,
        ServiceFieldType.calendar,
        label: '离校时间',
        sort: 40,
      ),
      plugin(
        kFieldReturnDate,
        ServiceFieldType.calendar,
        label: '返校时间',
        sort: 50,
      ),
      plugin(
        kFieldRegion,
        ServiceFieldType.region,
        label: ServiceFormFields.region.label,
        sort: 60,
      ),
      plugin('File_71', ServiceFieldType.file, label: '上传证明', sort: 70),
      plugin('Input_84', ServiceFieldType.input, label: '辅导员', sort: 80),
      plugin(
        'DataSource_85',
        ServiceFieldType.dataSource,
        label: '辅导员',
        sort: 90,
        dataSource: const ServiceDataSourceRef(
          id: ServiceApiService.tutorDataSourceId,
          formVersionId: formVersionId,
          component: 'DataSource_85',
          formId: '1419',
          resultKey: 'Input_84',
        ),
      ),
      // 占位字段（提交 ''，与已验证 payload 一致）
      plugin('Variate_75', ServiceFieldType.variate, sort: 100),
      // ShowHide_44 附带真实规则（350 抓包确认）：
      // Radio_67==7 时显示并必填 MultiInput_40，否则隐藏
      ServiceFormPlugin(
        key: 'ShowHide_44',
        type: ServiceFieldType.showHide,
        sort: 101,
        showHideRule: const ServiceShowHideRule(
          conditions: [
            ServiceShowHideCondition(name: '默认', expression: 'true'),
            ServiceShowHideCondition(
              name: '其他',
              expression: '{p_Radio_67}.indexOf(7)!==-1',
            ),
            ServiceShowHideCondition(
              name: '！其他',
              expression: '{p_Radio_67}.indexOf(7)==-1',
            ),
          ],
          controls: {
            '0': ServiceShowHideControl(
              isShow: false,
              isRequired: false,
              targets: ['MultiInput_40', 'Text_39'],
            ),
            '1': ServiceShowHideControl(
              isShow: true,
              isRequired: true,
              targets: ['MultiInput_40', 'Text_39'],
            ),
            '2': ServiceShowHideControl(
              isShow: false,
              isRequired: false,
              clearWhenHidden: true,
              targets: ['MultiInput_40', 'Text_39'],
            ),
          },
        ),
      ),
      plugin('ShowHide_83', ServiceFieldType.showHide, sort: 102),
      plugin('Validate_86', ServiceFieldType.validate, sort: 103),
      // 占位字段（提交 []）
      plugin('Conversion_74', ServiceFieldType.conversion, sort: 104),
      plugin('RepeatTable_76', ServiceFieldType.repeatTable, sort: 105),
    ],
  );
}

/// 办事大厅事项目录（驱动 ServiceHallPage 列表）。
final kServiceAppCatalog = <ServiceAppInfo>[
  ServiceAppInfo(
    appId: ServiceApiService.leaveAppId,
    icon: Icons.fact_check_outlined,
    title: (l) => l.serviceHallLeaveTitle,
    desc: (l) => l.serviceHallLeaveDesc,
    overrides: kApp350Overrides,
    fallbackSchema: buildLeaveFallbackSchema,
  ),
  ServiceAppInfo(
    appId: ServiceApiService.returnReportAppId,
    icon: Icons.home_work_outlined,
    title: (l) => l.serviceHallReturnTitle,
    desc: (l) => l.serviceHallReturnDesc,
  ),
  ServiceAppInfo(
    appId: ServiceApiService.summerLeaveAppId,
    icon: Icons.beach_access_outlined,
    title: (l) => l.serviceHallSummerLeaveTitle,
    desc: (l) => l.serviceHallSummerLeaveDesc,
  ),
  ServiceAppInfo(
    appId: ServiceApiService.stayRegisterAppId,
    icon: Icons.apartment_outlined,
    title: (l) => l.serviceHallStayRegisterTitle,
    desc: (l) => l.serviceHallStayRegisterDesc,
  ),
];
