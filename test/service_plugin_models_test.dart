import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/services/api/service_form_models.dart';
import 'package:bugaoshan/services/api/service_plugin_models.dart';

/// 构造一份仿真实结构的 get-formv `d` 字段（对照
/// test/fixtures/service_capture.json 中 350/337/356/357 的响应）：
/// plugins 为 JSON 字符串（二次编码），解码后是
/// `{nowNum, plugins: {<key>: <plugin>}, rtplugins}`；
/// 标签在顶层 `description`；DataSource 的 sourceid 是数字。
Map<String, dynamic> _fakeFormvD() {
  Map<String, dynamic> plugin(
    String key,
    String type,
    int sort,
    String description,
    Map<String, dynamic> data,
  ) => {
    'key': key,
    'type': type,
    'sort': sort,
    'description': description,
    'attr': {'data': data, 'style': const {}},
    'status': {'required': false, 'readonly': false, 'isshow': true},
  };

  final plugins = {
    'nowNum': 90,
    'plugins': {
      'User_21': plugin('User_21', 'dUser', 40, '学号', {
        'name': '发起者.学工号',
        'express': 'starter.starter.number',
      }),
      'Radio_30': plugin('Radio_30', 'dRadio', 110, '离开校区', {
        'options': [
          {'name': '望江校区', 'value': '1', 'default': 0},
          {'name': '华西校区', 'value': '2', 'default': 0},
          {'name': '江安校区', 'value': '3', 'default': 0},
        ],
      }),
      'Calendar_25': plugin('Calendar_25', 'dCalendar', 2, '离校时间', {
        'datetype': 'datetime',
      }),
      'MultiInput_40': plugin('MultiInput_40', 'dmultiInputs', 121, '其它事由', {
        'placeholder': '请填写具体事由',
      }),
      'File_71': plugin('File_71', 'dFile', 105, '上传证明', {
        'maxNum': 0,
        'buttontext': '上传证明（可上传1-3张图片）',
      }),
      'Ximage_52': plugin('Ximage_52', 'dXImage', 97, '相关材料上传（选填项）', {
        'maxNum': '5',
      }),
      'SelectV2_18': plugin('SelectV2_18', 'dSelectV2', 50, '宿舍所在校区', {
        'isMultiple': false,
        'options': [
          {'name': '望江校区', 'value': '1', 'default': 0, 'imgdata': ''},
          {'name': '校外住宿', 'value': '4', 'default': 0, 'imgdata': ''},
        ],
      }),
      'Region_80': plugin('Region_80', 'dRegion', 140, '目的地', {
        'limitval': '4',
      }),
      'Text_3': plugin('Text_3', 'dOneInput', 2030, '', {'showSort': 0}),
      'Image_81': plugin('Image_81', 'dImage', 2840, '', {}),
      'Table_1': plugin('Table_1', 'dTable', 1, '', {}),
      'DataSource_85': plugin(
        'DataSource_85',
        'dDataSource',
        2850,
        '数据源-审批辅导员',
        {
          'type': 1,
          'sourceid': 8, // 真实数据是数字
          'resultKey': 'Input_84',
          'mapConfig': {},
          'sourceConfig': {},
        },
      ),
      'DataSource_163': plugin(
        'DataSource_163',
        'dDataSource',
        3630,
        '数据源：年级和返校日期',
        {
          'type': 1,
          'sourceid': 11,
          'resultKey': 'setplugin',
          'mapConfig': {
            'User_156': {'key': 'grade', 'targetColumn': ''},
            'Input_162': {'key': 'back_date', 'targetColumn': ''},
          },
        },
      ),
      'Validate_62': plugin('Validate_62', 'dValidate', 2620, '验证信息-日期', {
        'rule': '{f_dateDayMinus}({p_Calendar_34},{p_Calendar_61})<0',
        'alert': '离校日期必须大于预计返校时间',
      }),
      'ShowHide_44': plugin('ShowHide_44', 'dShowHide', 2440, '逻辑显隐', {
        'num': 2,
        'conditions': [
          {'name': '默认', 'expression': 'true'},
          {'name': '其他', 'expression': '{p_Radio_67}.indexOf(7)!==-1'},
          {'name': '！其他', 'expression': '{p_Radio_67}.indexOf(7)==-1'},
        ],
        'controls': [
          {
            'conkey': '0',
            'setInfo': {
              'isShow': 0,
              'isEmpty': 2,
              'plugins': ['MultiInput_40', 'Text_39'],
              'isRequired': 2,
            },
          },
          {
            'conkey': '1',
            'setInfo': {
              'isShow': 1,
              'isEmpty': 2,
              'plugins': ['MultiInput_40', 'Text_39'],
              'isRequired': 1,
            },
          },
          {
            'conkey': '2',
            'setInfo': {
              'isShow': 0,
              'isEmpty': 1,
              'plugins': ['MultiInput_40', 'Text_39'],
              'isRequired': 0,
            },
          },
        ],
      }),
    },
    'rtplugins': <dynamic>[],
  };
  return {
    'id': 1419,
    'name': '学生离校请假（当天不能回校和成都市外）',
    'form_version_id': 2357,
    'plugins': jsonEncode(plugins),
  };
}

ServiceFormDefinition _fakeStartData() {
  return ServiceFormDefinition.fromJson({
    'currform': [1419],
    'auth': {
      '1419': {
        'User_21': 'require',
        'Radio_30': 'require',
        'Calendar_25': 'require',
        'MultiInput_40': 'writable',
        'File_71': 'writable',
        'Ximage_52': 'writable',
        'SelectV2_18': 'require',
        'Region_80': 'require',
        'DataSource_85': 'writable',
        'DataSource_163': 'writable',
        'ShowHide_44': 'writable',
        'Validate_62': 'writable',
        'Input_162': 'hidden',
        'User_156': 'forbidden',
      },
    },
    'data': {
      '1419': {'User_21': '2025141230072'},
    },
  });
}

void main() {
  group('resolveServiceFieldType', () {
    test('优先组件声明（真实组件名，大小写不敏感，去 d 前缀）', () {
      expect(resolveServiceFieldType('dRadio', 'X_1'), ServiceFieldType.radio);
      expect(resolveServiceFieldType('dInput', 'X_2'), ServiceFieldType.input);
      expect(
        resolveServiceFieldType('dmultiInputs', 'X_3'),
        ServiceFieldType.multiInput,
      );
      expect(
        resolveServiceFieldType('dmultiText', 'X_3b'),
        ServiceFieldType.multiInput,
      );
      expect(
        resolveServiceFieldType('dDataSource', 'X_4'),
        ServiceFieldType.dataSource,
      );
      expect(
        resolveServiceFieldType('dRegion', 'X_5'),
        ServiceFieldType.region,
      );
      expect(
        resolveServiceFieldType('dSelectV2', 'X_6'),
        ServiceFieldType.selectV2,
      );
      expect(resolveServiceFieldType('dXImage', 'X_7'), ServiceFieldType.file);
      expect(
        resolveServiceFieldType('dOneInput', 'X_8'),
        ServiceFieldType.text,
      );
      expect(resolveServiceFieldType('dImage', 'X_9'), ServiceFieldType.image);
      expect(resolveServiceFieldType('dTable', 'X_10'), ServiceFieldType.table);
    });

    test('声明缺失或不认识时按 key 前缀推断', () {
      expect(resolveServiceFieldType(null, 'Radio_30'), ServiceFieldType.radio);
      expect(
        resolveServiceFieldType('dUnknownNew', 'Calendar_25'),
        ServiceFieldType.calendar,
      );
      expect(
        resolveServiceFieldType(null, 'SelectV2_42'),
        ServiceFieldType.selectV2,
      );
      expect(
        resolveServiceFieldType(null, 'Ximage_181'),
        ServiceFieldType.file,
      );
      expect(
        resolveServiceFieldType(null, 'MultiText_6'),
        ServiceFieldType.multiInput,
      );
      expect(resolveServiceFieldType(null, 'Foo_1'), ServiceFieldType.unknown);
    });
  });

  group('ServiceFormSchema.build（真实 get-formv 结构）', () {
    test('解析插件并合并 start-data', () {
      final schema = ServiceFormSchema.build(
        appId: '350',
        formvD: _fakeFormvD(),
        startData: _fakeStartData(),
      );

      expect(schema.appId, '350');
      expect(schema.formId, '1419');
      expect(schema.formVersionId, '2357');
      expect(schema.plugins.length, 15);
      // sort 升序：Table_1(1) 在前，DataSource_163(3630) 在后
      expect(schema.plugins.first.key, 'Table_1');
      expect(schema.plugins.last.key, 'DataSource_163');

      // 标签取顶层 description（而非 attr.data.name 的绑定表达式名）
      final user = schema.pluginByKey('User_21')!;
      expect(user.label, '学号');

      final radio = schema.pluginByKey('Radio_30')!;
      expect(radio.type, ServiceFieldType.radio);
      expect(radio.label, '离开校区');
      expect(radio.options.length, 3);
      expect(radio.options[2].value, '3');
      expect(radio.options[2].label, '江安校区');

      final multi = schema.pluginByKey('MultiInput_40')!;
      expect(multi.type, ServiceFieldType.multiInput);
      expect(multi.hint, '请填写具体事由');

      // maxNum：数字 0 → 默认 3；字符串 '5' → 5
      expect(schema.pluginByKey('File_71')!.maxCount, 3);
      expect(schema.pluginByKey('Ximage_52')!.maxCount, 5);
      expect(schema.pluginByKey('Ximage_52')!.type, ServiceFieldType.file);

      // DataSource：sourceid 数字 → 字符串；resultKey 与 mapConfig 解析
      final ds = schema.pluginByKey('DataSource_85')!;
      expect(ds.dataSource, isNotNull);
      expect(ds.dataSource!.id, '8');
      expect(ds.dataSource!.formVersionId, '2357');
      expect(ds.dataSource!.resultKey, 'Input_84');
      expect(ds.dataSource!.isSetPlugin, isFalse);

      final ds2 = schema.pluginByKey('DataSource_163')!;
      expect(ds2.dataSource!.id, '11');
      expect(ds2.dataSource!.isSetPlugin, isTrue);
      expect(ds2.dataSource!.mapConfig, {
        'User_156': 'grade',
        'Input_162': 'back_date',
      });

      // Validate 日期规则
      final validate = schema.pluginByKey('Validate_62')!;
      expect(validate.dateOrderRule, isNotNull);
      expect(validate.dateOrderRule!.firstKey, 'Calendar_34');
      expect(validate.dateOrderRule!.secondKey, 'Calendar_61');
      expect(validate.dateOrderRule!.message, '离校日期必须大于预计返校时间');
      expect(schema.dateOrderRules.length, 1);

      // ShowHide 规则
      final showHide = schema.pluginByKey('ShowHide_44')!;
      expect(showHide.showHideRule, isNotNull);
      expect(showHide.showHideRule!.conditions.length, 3);
      expect(showHide.showHideRule!.controls['1']!.isShow, isTrue);
      expect(showHide.showHideRule!.controls['1']!.isRequired, isTrue);
      expect(showHide.showHideRule!.controls['0']!.isShow, isFalse);
      expect(showHide.showHideRule!.controls['0']!.isRequired, isFalse);
      expect(showHide.showHideRule!.controls['2']!.clearWhenHidden, isTrue);
    });

    test('editable/readonly/dataSource 视图按 auth 过滤（含 hidden/forbidden）', () {
      final schema = ServiceFormSchema.build(
        appId: '350',
        formvD: _fakeFormvD(),
        startData: _fakeStartData(),
      );
      final editable = schema.editablePlugins.map((p) => p.key).toList();
      // User_21 虽 auth=require，但 dUser 是自动字段 → 不可编辑
      expect(editable, isNot(contains('User_21')));
      // Text/Image/Table/ShowHide/Validate 占位不渲染
      for (final k in [
        'Text_3',
        'Image_81',
        'Table_1',
        'ShowHide_44',
        'Validate_62',
      ]) {
        expect(editable, isNot(contains(k)), reason: k);
      }
      // DataSource 不可编辑（自动取数）
      expect(editable, isNot(contains('DataSource_85')));
      // hidden/forbidden 字段不在插件列表则无影响（auth 孤儿 key）
      expect(
        editable,
        containsAll([
          'Radio_30',
          'Calendar_25',
          'MultiInput_40',
          'File_71',
          'Ximage_52',
          'SelectV2_18',
          'Region_80',
        ]),
      );
      // User_21 有预填 → 只读信息展示
      expect(schema.readonlyInfoPlugins.map((p) => p.key), ['User_21']);
      expect(schema.dataSourcePlugins.map((p) => p.key), [
        'DataSource_85',
        'DataSource_163',
      ]);
      expect(schema.activeShowHidePlugins.map((p) => p.key), ['ShowHide_44']);
      expect(schema.isRenderable, isTrue);
      expect(schema.isSuppressed('Input_162'), isTrue);
      expect(schema.isSuppressed('User_156'), isTrue);
      expect(schema.isSuppressed('Radio_30'), isFalse);
    });

    test('attr 为二次编码字符串时可解析', () {
      final d = _fakeFormvD();
      final decoded = jsonDecode(d['plugins'] as String) as Map;
      for (final e in (decoded['plugins'] as Map).entries) {
        (e.value as Map)['attr'] = jsonEncode((e.value as Map)['attr']);
      }
      d['plugins'] = jsonEncode(decoded);
      final schema = ServiceFormSchema.build(
        appId: '350',
        formvD: d,
        startData: _fakeStartData(),
      );
      expect(schema.pluginByKey('Radio_30')!.options.length, 3);
      expect(schema.pluginByKey('DataSource_85')!.dataSource!.id, '8');
    });

    test('type 缺失时按 key 前缀推断', () {
      final d = _fakeFormvD();
      final decoded = jsonDecode(d['plugins'] as String) as Map;
      for (final e in (decoded['plugins'] as Map).entries) {
        (e.value as Map).remove('type');
      }
      d['plugins'] = jsonEncode(decoded);
      final schema = ServiceFormSchema.build(
        appId: '350',
        formvD: d,
        startData: _fakeStartData(),
      );
      expect(schema.pluginByKey('Radio_30')!.type, ServiceFieldType.radio);
      expect(schema.pluginByKey('Region_80')!.type, ServiceFieldType.region);
      expect(
        schema.pluginByKey('SelectV2_18')!.type,
        ServiceFieldType.selectV2,
      );
      expect(schema.pluginByKey('Ximage_52')!.type, ServiceFieldType.file);
      expect(
        schema.pluginByKey('ShowHide_44')!.type,
        ServiceFieldType.showHide,
      );
      expect(schema.pluginByKey('Text_3')!.type, ServiceFieldType.text);
    });

    test('无插件抛 FormatException（走 fallback）', () {
      expect(
        () => ServiceFormSchema.build(
          appId: '350',
          formvD: const {'id': 1419},
          startData: _fakeStartData(),
        ),
        throwsFormatException,
      );
      expect(
        () => ServiceFormSchema.build(
          appId: '350',
          formvD: const {'id': 1419, 'plugins': '{"nowNum":0,"plugins":{}}'},
          startData: _fakeStartData(),
        ),
        throwsFormatException,
      );
    });

    test('占位字段空值规则复现 350 已验证 payload', () {
      expect(
        ServiceFormSchema.placeholderValueFor(ServiceFieldType.showHide),
        '',
      );
      expect(
        ServiceFormSchema.placeholderValueFor(ServiceFieldType.variate),
        '',
      );
      expect(
        ServiceFormSchema.placeholderValueFor(ServiceFieldType.validate),
        '',
      );
      expect(
        ServiceFormSchema.placeholderValueFor(ServiceFieldType.conversion),
        isA<List>(),
      );
      expect(
        ServiceFormSchema.placeholderValueFor(ServiceFieldType.repeatTable),
        isA<List>(),
      );
      expect(
        ServiceFormSchema.placeholderValueFor(ServiceFieldType.selectV2),
        isA<List>(),
      );
      expect(
        ServiceFormSchema.placeholderValueFor(ServiceFieldType.file),
        isA<List>(),
      );
    });
  });

  group('evalServiceShowHideExpression（实表条件形态）', () {
    Object? Function(String) valueOf(Map<String, Object?> values) =>
        (String key) => values[key];

    test('true/false 与 radio 比较/包含', () {
      expect(evalServiceShowHideExpression('true', valueOf({})), isTrue);
      expect(evalServiceShowHideExpression('false', valueOf({})), isFalse);
      // 350: Radio_67 选 7 显示其它事由
      expect(
        evalServiceShowHideExpression(
          '{p_Radio_67}.indexOf(7)!==-1',
          valueOf({'Radio_67': '7'}),
        ),
        isTrue,
      );
      expect(
        evalServiceShowHideExpression(
          '{p_Radio_67}.indexOf(7)==-1',
          valueOf({'Radio_67': '6'}),
        ),
        isTrue,
      );
      // 357: Radio_39==5
      expect(
        evalServiceShowHideExpression(
          '{p_Radio_39}==5',
          valueOf({'Radio_39': '5'}),
        ),
        isTrue,
      );
      expect(
        evalServiceShowHideExpression(
          '{p_Radio_39}!=5',
          valueOf({'Radio_39': '5'}),
        ),
        isFalse,
      );
    });

    test('SelectV2 数组取值比较', () {
      // 337: {p_SelectV2_186}[0].value==5
      expect(
        evalServiceShowHideExpression(
          '{p_SelectV2_186}[0].value==5',
          valueOf({'SelectV2_186': '5'}),
        ),
        isTrue,
      );
      expect(
        evalServiceShowHideExpression(
          '{p_SelectV2_186}[0].value!=5',
          valueOf({'SelectV2_186': '1'}),
        ),
        isTrue,
      );
      // 357 ShowHide_46: {p_SelectV2_42}[0]==2
      expect(
        evalServiceShowHideExpression(
          '{p_SelectV2_42}[0]==2',
          valueOf({'SelectV2_42': '2'}),
        ),
        isTrue,
      );
    });

    test('日期比较（337 早到判断）', () {
      final values = {'Calendar_86': DateTime(2023, 2, 10)};
      expect(
        evalServiceShowHideExpression(
          "new Date({p_Calendar_86}) <= new Date('2023-02-12')",
          valueOf(values),
        ),
        isTrue,
      );
      expect(
        evalServiceShowHideExpression(
          "new Date({p_Calendar_86}) > new Date('2023-02-12')",
          valueOf(values),
        ),
        isFalse,
      );
      // 字符串值（服务端预填形态）也可比较
      expect(
        evalServiceShowHideExpression(
          "new Date({p_Calendar_86}) > new Date('2023-02-12')",
          valueOf({'Calendar_86': '2026-08-10T17:10:21+'}),
        ),
        isTrue,
      );
    });

    test('文本包含 / 空串 / || 复合', () {
      expect(
        evalServiceShowHideExpression(
          "{p_MultiInput_43}.includes('同意')",
          valueOf({'MultiInput_43': '审批意见：同意'}),
        ),
        isTrue,
      );
      expect(
        evalServiceShowHideExpression(
          "{p_MultiInput_43}==''",
          valueOf({'MultiInput_43': ''}),
        ),
        isTrue,
      );
      // 356 ShowHide_37 的复合形态
      expect(
        evalServiceShowHideExpression(
          "{p_MultiInput_43}.includes('驳回')||{p_MultiInput_43}==''",
          valueOf({'MultiInput_43': ''}),
        ),
        isTrue,
      );
      expect(
        evalServiceShowHideExpression(
          "{p_MultiInput_43}.includes('驳回')||{p_MultiInput_43}==''",
          valueOf({'MultiInput_43': '同意'}),
        ),
        isFalse,
      );
    });

    test('未支持形态返回 null（按不命中处理）', () {
      expect(
        evalServiceShowHideExpression(
          '{f_someFunc}({p_X})>2',
          valueOf({'X': '1'}),
        ),
        isNull,
      );
    });
  });
}
