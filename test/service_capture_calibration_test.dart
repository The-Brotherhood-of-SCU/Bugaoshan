import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/services/api/service_form_models.dart';
import 'package:bugaoshan/services/api/service_plugin_models.dart';
import 'package:bugaoshan/pages/campus/service_hall/service_form_controller.dart';
import 'package:bugaoshan/widgets/common/service_region_picker.dart';

/// 用真实抓包（tools/capture_api.js + 被动捕获导出）端到端校准解析器：
/// 真实 start-data + 真实 get-formv → schema → 模拟填写 → 组装提交体检查。
///
/// 数据文件：`test/fixtures/service_capture.json`（主动探测导出）。
/// 文件不存在时整组 skip（CI/常规测试不受影响）。
///
/// 覆盖断言（全部来自抓包确认的事实）：
///  - 4 个事项的 schema 均可解析且 isRenderable；
///  - 字段类型/标签/选项与实表一致（337 的 SelectV2、356 的校外住宿等）；
///  - ShowHide 引擎复现实表显隐（350 其它事由、337 其他返校原因、
///    357 全假期留校/研究生分类联动）；
///  - Validate 日期规则解析（356/357）；
///  - DataSource ref（resultKey / setplugin mapConfig）解析；
///  - 模拟填写后的 buildFormData 结构（占位、配对、孤儿 key、隐藏字段）。
void main() {
  final file = File('test/fixtures/service_capture.json');
  if (!file.existsSync()) {
    test('capture fixture 不存在，跳过校准（见文件头注释）', () {}, skip: true);
    return;
  }

  final dump = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final requests = (dump['requests'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic>? findJson(String name) {
    for (final r in requests.reversed) {
      if (r['name'] == name && r['json'] is Map<String, dynamic>) {
        return r['json'] as Map<String, dynamic>;
      }
    }
    return null;
  }

  ServiceFormSchema buildFor(String appId, String formId) {
    final dataJson = findJson('start-data app=$appId')!;
    final formvJson = findJson('get-formv app=$appId form=$formId')!;
    return ServiceFormSchema.build(
      appId: appId,
      formvD: Map<String, dynamic>.from(formvJson['d'] as Map),
      // fromJson 要的是 d 层（currform/auth/data），不是整个响应信封
      startData: ServiceFormDefinition.fromJson(
        Map<String, dynamic>.from(dataJson['d'] as Map),
      ),
    );
  }

  ServiceRegionSelection fakeRegion() {
    const p = ServiceRegionNode(label: '四川省', value: '510000');
    const c = ServiceRegionNode(label: '成都市', value: '510100');
    const a = ServiceRegionNode(label: '武侯区', value: '510107');
    return const ServiceRegionSelection(
      province: p,
      city: c,
      area: a,
      details: '望江校区北门',
    );
  }

  group('真实抓包端到端校准', () {
    test('350 离校请假：schema 与已验证行为一致', () {
      final schema = buildFor('350', '1419');
      expect(schema.isRenderable, isTrue);
      expect(schema.formVersionId, '2357');

      // 关键字段
      expect(schema.pluginByKey('Radio_30')!.options.length, 3);
      expect(schema.pluginByKey('Radio_67')!.label, '事由');
      expect(schema.pluginByKey('Region_80')!.label, '目的地');
      expect(
        schema.pluginByKey('DataSource_85')!.dataSource!.resultKey,
        'Input_84',
      );

      // User_* auth=require 但不可编辑（自动字段）
      final editable = schema.editablePlugins.map((p) => p.key).toList();
      expect(editable, isNot(contains('User_21')));
      expect(
        editable,
        containsAll([
          'Radio_30',
          'Radio_67',
          'MultiInput_40',
          'Calendar_25',
          'Calendar_26',
          'Region_80',
          'File_71',
        ]),
      );

      // ShowHide：44/83 writable 生效（68 readable 审批侧被过滤）。
      // 83 的规则作用于静态图 Image_81、条件引用审批侧 MultiInput_35，
      // 对发起表单是 no-op，但按"writable 即生效"规则会被收录。
      expect(schema.activeShowHidePlugins.map((p) => p.key), [
        'ShowHide_44',
        'ShowHide_83',
      ]);

      final c = ServiceFormController(schema);
      final detail = schema.pluginByKey('MultiInput_40')!;
      c.values['Radio_67'] = '6';
      expect(c.isFieldVisible(detail), isFalse);
      c.values['Radio_67'] = '7';
      expect(c.isFieldVisible(detail), isTrue);
      expect(c.isFieldRequired('MultiInput_40'), isTrue);

      // 模拟完整填写 → payload 结构（与 PR 已验证形态一致）
      c.values['Radio_30'] = '3';
      c.values['MultiInput_40'] = '参加婚礼';
      c.values['Calendar_25'] = DateTime(2026, 8, 12);
      c.values['Calendar_26'] = DateTime(2026, 8, 20);
      c.values['Region_80'] = fakeRegion();
      c.applyDataSourceValue(schema.pluginByKey('DataSource_85')!, '马力');
      final fields = c.buildFormData()['1419']!;
      expect(fields['Radio_30'], {'value': '3', 'name': '江安校区'});
      expect(fields['DataSource_85'], {'list': '马力'});
      expect(fields['Input_84'], '马力');
      expect(fields['User_22'], '王金华'); // 真实预填透传
      expect(fields['ShowHide_44'], '');
      expect(fields['Conversion_74'], isA<List>());
      expect(fields['Region_78'], ''); // 孤儿 key 占位
      expect(fields['MultiInput_40'], '参加婚礼');
    });

    test('337 返校报备：双 DataSource + 早到逻辑 + 孤儿 require', () {
      final schema = buildFor('337', '1396');
      expect(schema.isRenderable, isTrue);
      expect(schema.formVersionId, '2282');

      // currform 是 1396（返校信息填报），不是 1397（人群说明）
      expect(schema.formId, '1396');

      // SelectV2 解析
      final sv = schema.pluginByKey('SelectV2_186')!;
      expect(sv.type, ServiceFieldType.selectV2);
      expect(sv.options.length, 5);
      expect(sv.options.last.value, '5');
      expect(sv.options.last.label, '其他原因');

      // Ximage → file
      expect(schema.pluginByKey('Ximage_181')!.type, ServiceFieldType.file);

      // 双 DataSource
      final ds139 = schema.pluginByKey('DataSource_139')!.dataSource!;
      expect(ds139.id, '8');
      expect(ds139.resultKey, 'Input_157');
      final ds163 = schema.pluginByKey('DataSource_163')!.dataSource!;
      expect(ds163.id, '11');
      expect(ds163.isSetPlugin, isTrue);
      expect(ds163.mapConfig, {'User_156': 'grade', 'Input_162': 'back_date'});

      // Input_162 auth=hidden（DataSource 可能写入，不渲染）
      expect(schema.isSuppressed('Input_162'), isTrue);
      // SelectV2_184 孤儿 require（插件不存在，校验不拦截）
      expect(schema.pluginByKey('SelectV2_184'), isNull);
      expect(schema.isRequired('SelectV2_184'), isTrue);

      final c = ServiceFormController(schema);
      // 日历预填（'2026-08-10T17:10:21+'）播种为 DateTime
      expect(c.values['Calendar_86'], isA<DateTime>());

      // ShowHide_194：Calendar_86 晚于 2023-02-12 → SelectV2_186 隐藏
      final svField = schema.pluginByKey('SelectV2_186')!;
      expect(c.isFieldVisible(svField), isFalse);
      // 若早到（<=2023-02-12）→ 显示且必填
      c.values['Calendar_86'] = DateTime(2023, 2, 1);
      expect(c.isFieldVisible(svField), isTrue);
      expect(c.isFieldRequired('SelectV2_186'), isTrue);
      // ShowHide_189：事由=其他(5) → Input_188 显示且必填
      c.values['SelectV2_186'] = '5';
      final i188 = schema.pluginByKey('Input_188')!;
      expect(c.isFieldVisible(i188), isTrue);
      expect(c.isFieldRequired('Input_188'), isTrue);
      c.values['SelectV2_186'] = '1';
      expect(c.isFieldVisible(i188), isFalse);

      // setplugin 分发：grade→User_156（auth=require 的用户字段被填充）
      c.applyDataSourceValue(schema.pluginByKey('DataSource_163')!, {
        'grade': '2023',
        'back_date': '',
      });
      expect(c.values['User_156'], '2023');

      // 模拟填写（正常时间到校：事由隐藏）→ payload
      c.values['Calendar_86'] = DateTime(2026, 8, 25);
      c.values['Radio_101'] = '1';
      c.values['Radio_61'] = '3';
      c.values['Region_105'] = fakeRegion();
      c.applyDataSourceValue(schema.pluginByKey('DataSource_139')!, '马力');
      final fields = c.buildFormData()['1396']!;
      expect(fields['Radio_101'], {'value': '1', 'name': '男'});
      expect(fields['Radio_61'], {'value': '3', 'name': '江安校区'});
      expect(fields['User_156'], '2023');
      expect(fields['DataSource_139'], {'list': '马力'});
      expect(fields['Input_157'], '马力');
      expect(fields['SelectV2_186'], isA<List>()); // 隐藏 → []
      expect(fields['SelectV2_184'], isA<List>()); // 孤儿 → []
      expect(fields['Ximage_181'], isA<List>());
      expect(fields['Input_162'], '');
      expect(fields['Input_188'], '');
      expect(fields.containsKey('DataSource_163'), isFalse);
    });

    test('356 暑假离校：日期 Validate 规则 + 校外住宿选项', () {
      final schema = buildFor('356', '1424');
      expect(schema.isRenderable, isTrue);
      expect(schema.formVersionId, '2653');

      final sv = schema.pluginByKey('SelectV2_18')!;
      expect(sv.type, ServiceFieldType.selectV2);
      expect(sv.options.length, 4);
      expect(sv.options.last.label, '校外住宿');

      // Validate_62 日期规则
      expect(schema.dateOrderRules.length, 1);
      final rule = schema.dateOrderRules.single;
      expect(rule.firstKey, 'Calendar_34');
      expect(rule.secondKey, 'Calendar_61');

      final c = ServiceFormController(schema);
      c.values['SelectV2_18'] = '4';
      c.values['Calendar_34'] = DateTime(2026, 7, 10);
      c.values['Calendar_61'] = DateTime(2026, 8, 30);
      c.values['Region_50'] = fakeRegion();
      c.applyDataSourceValue(schema.pluginByKey('DataSource_60')!, '马力');
      expect(c.validate(), isNull);

      // 返校早于离校 → 服务端 alert 原文
      c.values['Calendar_61'] = DateTime(2026, 7, 1);
      final issue = c.validate();
      expect(issue, isNotNull);
      expect(issue!.kind, ServiceValidationKind.custom);
      expect(issue.message, '离校日期必须大于预计返校时间');

      final fields = c.buildFormData()['1424']!;
      expect(fields['SelectV2_18'], [
        {'value': '4', 'name': '校外住宿'},
      ]);
      expect(fields['DataSource_60'], {'list': '马力'});
      expect(fields['Input_59'], '马力');
      // forbidden 孤儿（User_23/Calendar_24/MultiInput_22）→ 占位 ''
      expect(fields['User_23'], '');
      expect(fields['Calendar_24'], '');
      expect(fields['MultiInput_43'], ''); // hidden 孤儿
    });

    test('357 留校登记：身份三级联动 + 全假期日期联动', () {
      final schema = buildFor('357', '1426');
      expect(schema.isRenderable, isTrue);
      expect(schema.formVersionId, '2652');

      expect(schema.pluginByKey('SelectV2_42')!.options.length, 3);
      expect(schema.pluginByKey('SelectV2_43')!.options.length, 4);
      expect(schema.pluginByKey('SelectV2_44')!.options.length, 6);

      final c = ServiceFormController(schema);
      final sv43 = schema.pluginByKey('SelectV2_43')!;
      final sv44 = schema.pluginByKey('SelectV2_44')!;
      final c15 = schema.pluginByKey('Calendar_15')!;
      final c16 = schema.pluginByKey('Calendar_16')!;

      // 默认（身份未选）：43/44 都隐藏
      expect(c.isFieldVisible(sv43), isFalse);
      expect(c.isFieldVisible(sv44), isFalse);
      // 全假期=是(1)：留校起止时间隐藏
      c.values['Radio_18'] = '1';
      expect(c.isFieldVisible(c15), isFalse);
      expect(c.isFieldVisible(c16), isFalse);
      // 全假期=否(2)：显示且必填
      c.values['Radio_18'] = '2';
      expect(c.isFieldVisible(c15), isTrue);
      expect(c.isFieldRequired('Calendar_15'), isTrue);
      // 身份=研究生(2)：43 显示必填，44 隐藏
      c.values['SelectV2_42'] = '2';
      expect(c.isFieldVisible(sv43), isTrue);
      expect(c.isFieldRequired('SelectV2_43'), isTrue);
      expect(c.isFieldVisible(sv44), isFalse);
      // 身份=其他层次(3)：44 显示且必填（ShowHide_45 ctrl3 isRequired=1），43 隐藏
      c.values['SelectV2_42'] = '3';
      expect(c.isFieldVisible(sv43), isFalse);
      expect(c.isFieldVisible(sv44), isTrue);
      expect(c.isFieldRequired('SelectV2_44'), isTrue);
      // 留校原因=其他(5) → Input_38 显示必填
      c.values['Radio_39'] = '5';
      expect(c.isFieldVisible(schema.pluginByKey('Input_38')!), isTrue);
      expect(c.isFieldRequired('Input_38'), isTrue);

      // 模拟完整填写 → validate + payload（身份=其他层次 → 44 必填需填）
      c.values['Radio_39'] = '1';
      c.values['Radio_55'] = '1';
      c.values['SelectV2_44'] = '4';
      c.values['MultiInput_53'] = '江安校区西园';
      c.values['Calendar_15'] = DateTime(2026, 7, 15);
      c.values['Calendar_16'] = DateTime(2026, 8, 25);
      c.applyDataSourceValue(schema.pluginByKey('DataSource_66')!, '马力');
      expect(c.validate(), isNull);

      final fields = c.buildFormData()['1426']!;
      expect(fields['Radio_18'], {'value': '2', 'name': '否'});
      expect(fields['Radio_39'], {'value': '1', 'name': '学习科研'});
      expect(fields['Radio_55'], {'value': '1', 'name': '望江校区'});
      expect(fields['MultiInput_53'], '江安校区西园');
      expect(fields['DataSource_66'], {'list': '马力'});
      expect(fields['Input_65'], '马力');
      // 身份=其他层次 → SelectV2_44 提交 [{...}]，SelectV2_43 隐藏 → []
      expect(fields['SelectV2_44'], [
        {'value': '4', 'name': '留学生'},
      ]);
      expect(fields['SelectV2_43'], isA<List>());
      expect(fields['Input_38'], ''); // 原因≠其他 → 隐藏 ''
    });
  });
}
