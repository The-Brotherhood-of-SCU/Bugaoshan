import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/pages/campus/service_hall/service_app_catalog.dart';
import 'package:bugaoshan/pages/campus/service_hall/service_form_controller.dart';
import 'package:bugaoshan/services/api/service_api_service.dart';
import 'package:bugaoshan/services/api/service_form_fields.dart'
    show ServiceFieldOption;
import 'package:bugaoshan/services/api/service_form_models.dart';
import 'package:bugaoshan/services/api/service_plugin_models.dart';
import 'package:bugaoshan/widgets/common/service_region_picker.dart';

/// 350（离校请假）的真实 start-data 样例（auth 结构对照
/// test/fixtures/service_capture.json 的 start-data app=350：
/// User_21~24 为 require、Input_84 为 front_readonly、ShowHide_68 为
/// readable、Region_78 为孤儿 key（插件列表中没有）；
/// 预填值用脱敏假数据）。
ServiceFormDefinition realStartData350() {
  return ServiceFormDefinition.fromJson({
    'currform': [1419],
    'auth': {
      '1419': {
        'File_71': 'writable',
        'User_21': 'require',
        'User_22': 'require',
        'User_23': 'require',
        'User_24': 'require',
        'Input_84': 'front_readonly',
        'Radio_30': 'require',
        'Radio_67': 'require',
        'Region_80': 'require',
        'Variate_75': 'writable',
        'Calendar_25': 'require',
        'Calendar_26': 'require',
        'ShowHide_44': 'writable',
        'ShowHide_68': 'readable',
        'ShowHide_83': 'writable',
        'Validate_86': 'writable',
        'Conversion_74': 'writable',
        'DataSource_85': 'writable',
        'MultiInput_40': 'writable',
        'RepeatTable_76': 'writable',
        'Region_78': 'writable',
      },
    },
    'data': {
      '1419': {
        'User_21': '2025141230072',
        'User_22': '张三',
        'User_23': '计算机学院',
        'User_24': '13800000000',
      },
    },
  });
}

ServiceFormController makeController() {
  final schema = buildLeaveFallbackSchema(realStartData350());
  return ServiceFormController(schema, overrides: kApp350Overrides);
}

ServiceRegionSelection chengduRegion() {
  const sichuan = ServiceRegionNode(label: '四川省', value: '510000');
  const chengdu = ServiceRegionNode(label: '成都市', value: '510100');
  const wuhou = ServiceRegionNode(label: '武侯区', value: '510107');
  return const ServiceRegionSelection(
    province: sichuan,
    city: chengdu,
    area: wuhou,
    details: '望江校区北门',
  );
}

void main() {
  group('buildFormData 复现 350 已验证提交体', () {
    test('完整填写（事由=其它）逐字段相等', () {
      final c = makeController();
      c.values['Radio_30'] = '3';
      c.values['Radio_67'] = '7';
      c.values['MultiInput_40'] = '参加婚礼';
      c.values['Calendar_25'] = DateTime(2026, 8, 12);
      c.values['Calendar_26'] = DateTime(2026, 8, 20);
      c.values['Region_80'] = chengduRegion();
      c.values['File_71'] = <ServiceAttachment>[
        const ServiceAttachment(
          name: '图片1.png',
          url:
              'https://service.scu.edu.cn/site/attach/auth-download?file_id=1774464',
          id: '1774464',
        ),
      ];
      // 辅导员取数（单值模式：本字段 + resultKey 配对 Input_84）
      c.applyDataSourceValue(c.schema.pluginByKey('DataSource_85')!, '张美成');

      final data = c.buildFormData();
      expect(data.keys, ['1419']);
      final fields = data['1419']!;

      // 预填播种（User_* 虽 auth=require，但作为 dUser 自动字段透传）
      expect(fields['User_21'], '2025141230072');
      expect(fields['User_24'], '13800000000');
      // Radio → {value, name}
      expect(fields['Radio_30'], {'value': '3', 'name': '江安校区'});
      expect(fields['Radio_67'], {'value': '7', 'name': '其它'});
      // Calendar → UTC ISO
      expect(
        fields['Calendar_25'],
        DateTime(2026, 8, 12).toUtc().toIso8601String(),
      );
      // Region → 五级结构
      expect(fields['Region_80'], {
        'province': {'label': '四川省', 'value': '510000'},
        'city': {'label': '成都市', 'value': '510100'},
        'area': {'label': '武侯区', 'value': '510107'},
        'details': '望江校区北门',
        'address': '四川省/成都市/武侯区/望江校区北门',
      });
      // File → [{name, url, id}]
      expect(fields['File_71'], [
        {
          'name': '图片1.png',
          'url':
              'https://service.scu.edu.cn/site/attach/auth-download?file_id=1774464',
          'id': '1774464',
        },
      ]);
      // DataSource → {list: name} + resultKey 配对 Input（resultKey 来自
      // 插件配置，fallback schema 已内置 Input_84）
      expect(fields['DataSource_85'], {'list': '张美成'});
      expect(fields['Input_84'], '张美成');
      // 占位字段 '' / []
      expect(fields['Variate_75'], '');
      expect(fields['ShowHide_44'], '');
      expect(fields['ShowHide_83'], '');
      expect(fields['ShowHide_68'], ''); // readable 审批侧规则，占位
      expect(fields['Validate_86'], '');
      expect(fields['Conversion_74'], isA<List>());
      expect(fields['RepeatTable_76'], isA<List>());
      // 孤儿 auth key（插件已删的 Region_78）→ 占位 ''
      expect(fields['Region_78'], '');
      // 条件字段显示时提交内容
      expect(fields['MultiInput_40'], '参加婚礼');
    });

    test('事由=回家(6)时 MultiInput_40 隐藏并提交空串', () {
      final c = makeController();
      c.values['Radio_30'] = '1';
      c.values['Radio_67'] = '6';
      c.values['Calendar_25'] = DateTime(2026, 8, 12);
      c.values['Calendar_26'] = DateTime(2026, 8, 20);
      c.values['Region_80'] = chengduRegion();
      c.applyDataSourceValue(c.schema.pluginByKey('DataSource_85')!, '张美成');

      final detail = c.schema.pluginByKey('MultiInput_40')!;
      expect(c.isFieldVisible(detail), isFalse);
      final fields = c.buildFormData()['1419']!;
      expect(fields['MultiInput_40'], '');
      expect(fields['Radio_67'], {'value': '6', 'name': '回家'});
    });

    test('辅导员取数为空时省略 Input_84 / DataSource_85（已验证行为）', () {
      final c = makeController();
      c.values['Radio_30'] = '3';
      c.values['Radio_67'] = '6';
      c.values['Calendar_25'] = DateTime(2026, 8, 12);
      c.values['Calendar_26'] = DateTime(2026, 8, 20);
      c.values['Region_80'] = chengduRegion();

      final fields = c.buildFormData()['1419']!;
      expect(fields.containsKey('Input_84'), isFalse);
      expect(fields.containsKey('DataSource_85'), isFalse);
    });

    test('File_71 无附件时恒提交空数组', () {
      final c = makeController();
      c.values['Radio_30'] = '3';
      c.values['Radio_67'] = '6';
      c.values['Calendar_25'] = DateTime(2026, 8, 12);
      c.values['Calendar_26'] = DateTime(2026, 8, 20);
      c.values['Region_80'] = chengduRegion();

      final fields = c.buildFormData()['1419']!;
      expect(fields['File_71'], isA<List>());
      expect(fields['File_71'], isEmpty);
    });
  });

  group('ShowHide 动态显隐与必填（fallback 内置真实规则）', () {
    test('Radio_67=7 → MultiInput_40 显示且必填；=6 → 隐藏非必填', () {
      final c = makeController();
      final detail = c.schema.pluginByKey('MultiInput_40')!;
      c.values['Radio_67'] = '7';
      expect(c.isFieldVisible(detail), isTrue);
      expect(c.isFieldRequired('MultiInput_40'), isTrue);
      c.values['Radio_67'] = '6';
      expect(c.isFieldVisible(detail), isFalse);
      expect(c.isFieldRequired('MultiInput_40'), isFalse);
    });

    test('readable 的 ShowHide_68（审批侧）不参与发起节点显隐', () {
      final schema = buildLeaveFallbackSchema(realStartData350());
      // fallback 未收录 ShowHide_68 的规则；即使收录也应被 auth=readable 过滤
      expect(schema.activeShowHidePlugins.map((p) => p.key), ['ShowHide_44']);
    });
  });

  group('validate', () {
    Map<String, Object?> validValues() => {
      'Radio_30': '3',
      'Radio_67': '6',
      'Calendar_25': DateTime(2026, 8, 12),
      'Calendar_26': DateTime(2026, 8, 20),
      'Region_80': chengduRegion(),
    };

    test('全部必填填写后通过', () {
      final c = makeController();
      c.values.addAll(validValues());
      expect(c.validate(), isNull);
    });

    test('缺少必填 Radio 返回 required 问题', () {
      final c = makeController();
      c.values.addAll(validValues());
      c.values.remove('Radio_30');
      final issue = c.validate();
      expect(issue, isNotNull);
      expect(issue!.kind, ServiceValidationKind.required);
      expect(issue.fieldKey, 'Radio_30');
    });

    test('缺少必填 Region 返回 required 问题', () {
      final c = makeController();
      c.values.addAll(validValues());
      c.values.remove('Region_80');
      expect(c.validate()!.fieldKey, 'Region_80');
    });

    test('事由=其它(7)时其它事由为空 → 动态必填拦截', () {
      final c = makeController();
      c.values.addAll(validValues());
      c.values['Radio_67'] = '7';
      final issue = c.validate();
      expect(issue, isNotNull);
      expect(issue!.kind, ServiceValidationKind.required);
      expect(issue.fieldKey, 'MultiInput_40');
    });

    test('返校时间早于离校时间触发自定义校验', () {
      final c = makeController();
      c.values.addAll(validValues());
      c.values['Calendar_26'] = DateTime(2026, 8, 10);
      final issue = c.validate();
      expect(issue, isNotNull);
      expect(issue!.kind, ServiceValidationKind.custom);
      expect(issue.fieldKey, 'Calendar_26');
    });

    test('隐藏字段不阻塞提交', () {
      final c = makeController();
      c.values.addAll(validValues());
      // Radio_67=6 → MultiInput_40 隐藏
      expect(c.validate(), isNull);
    });
  });

  group('孤儿 auth key 兜底', () {
    test('auth 中出现但插件未覆盖的 key 按前缀规则给空值', () {
      final startData = ServiceFormDefinition.fromJson({
        'currform': [1419],
        'auth': {
          '1419': {
            'Radio_30': 'require',
            'Conversion_99': 'writable', // 插件列表里没有 → 兜底 []
            'Variate_98': 'writable', // → 兜底 ''
            'SelectV2_184': 'require', // 337 真实孤儿 → 兜底 []
          },
        },
        'data': {'1419': {}},
      });
      final schema = buildLeaveFallbackSchema(startData);
      final c = ServiceFormController(schema, overrides: kApp350Overrides);
      c.values['Radio_30'] = '2';
      final fields = c.buildFormData()['1419']!;
      expect(fields['Conversion_99'], isA<List>());
      expect(fields['Variate_98'], '');
      expect(fields['SelectV2_184'], isA<List>());
      expect(fields['Radio_30'], {'value': '2', 'name': '华西校区'});
    });
  });

  group('selectV2 / applyDataSourceValue / 预填播种', () {
    test('selectV2 序列化为 [{value, name}] 数组（前端 setComPluginData 确认）', () {
      const p = ServiceFormPlugin(
        key: 'SelectV2_18',
        type: ServiceFieldType.selectV2,
        options: [
          ServiceFieldOption('1', '望江校区'),
          ServiceFieldOption('4', '校外住宿'),
        ],
      );
      expect(serializeServiceFieldValue(p, '4'), [
        {'value': '4', 'name': '校外住宿'},
      ]);
      expect(serializeServiceFieldValue(p, ''), isA<List>());
      expect(serializeServiceFieldValue(p, null), isA<List>());
    });

    test('setplugin 模式按 mapConfig 分发多列（337 年级和返校日期）', () {
      final schema = ServiceFormSchema(
        appId: '337',
        formId: '1396',
        formVersionId: '2282',
        auth: const {
          'User_156': 'require',
          'Input_162': 'hidden',
          'DataSource_163': 'writable',
        },
        data: const {},
        plugins: const [
          ServiceFormPlugin(
            key: 'User_156',
            type: ServiceFieldType.user,
            label: '年级',
          ),
          ServiceFormPlugin(
            key: 'Input_162',
            type: ServiceFieldType.input,
            label: '规定到校日期',
          ),
          ServiceFormPlugin(
            key: 'DataSource_163',
            type: ServiceFieldType.dataSource,
            dataSource: ServiceDataSourceRef(
              id: '11',
              formVersionId: '2282',
              component: 'DataSource_163',
              formId: '1396',
              resultKey: 'setplugin',
              mapConfig: {'User_156': 'grade', 'Input_162': 'back_date'},
            ),
          ),
        ],
      );
      final c = ServiceFormController(schema);
      c.applyDataSourceValue(schema.pluginByKey('DataSource_163')!, {
        'grade': '2023',
        'back_date': '',
      });
      expect(c.values['User_156'], '2023');
      expect(c.values.containsKey('Input_162'), isFalse); // 空列不写入
      final fields = c.buildFormData()['1396']!;
      expect(fields['User_156'], '2023');
      // DataSource_163 自身无单值 → 省略；Input_162 hidden 无值 → ''
      expect(fields.containsKey('DataSource_163'), isFalse);
      expect(fields['Input_162'], '');
    });

    test('calendar 预填字符串宽容解析为 DateTime（337 的截断时区形态）', () {
      expect(parseServiceDateTime('2026-08-10T17:10:21+'), isNotNull);
      expect(parseServiceDateTime('2026-08-10'), DateTime(2026, 8, 10));
      expect(parseServiceDateTime(''), isNull);
      expect(parseServiceDateTime(null), isNull);
      final schema = ServiceFormSchema(
        appId: '337',
        formId: '1396',
        auth: const {'Calendar_86': 'require'},
        data: const {'Calendar_86': '2026-08-10T17:10:21+'},
        plugins: const [
          ServiceFormPlugin(
            key: 'Calendar_86',
            type: ServiceFieldType.calendar,
            label: '预计到校日期',
          ),
        ],
      );
      final c = ServiceFormController(schema);
      expect(c.values['Calendar_86'], isA<DateTime>());
      expect((c.values['Calendar_86'] as DateTime).day, 10);
    });
  });

  group('displayPlugins（350 用 fieldOrder 修正异常 sort）', () {
    test('按 override 顺序排列，未列出的按 sort 排后', () {
      final c = makeController();
      final order = c.displayPlugins.map((p) => p.key).toList();
      // kApp350Overrides.fieldOrder 的前几位
      final r30 = order.indexOf('Radio_30');
      final r67 = order.indexOf('Radio_67');
      final mi40 = order.indexOf('MultiInput_40');
      final c25 = order.indexOf('Calendar_25');
      final c26 = order.indexOf('Calendar_26');
      expect(r30, lessThan(r67));
      expect(r67, lessThan(mi40));
      expect(mi40, lessThan(c25));
      expect(c25, lessThan(c26));
    });
  });

  group('labelOf', () {
    test('服务端 label 优先，缺失时 override，最后 key', () {
      final c = makeController();
      final radio = c.schema.pluginByKey('Radio_30')!;
      expect(c.labelOf(radio), '离开校区');
    });
  });
}
