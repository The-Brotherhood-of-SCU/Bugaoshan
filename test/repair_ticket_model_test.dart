import 'package:bugaoshan/models/repair.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RepairTicket.fromDynamicJson content 解析', () {
    test('标准 JSON 字符串（含服务单位）正常解析', () {
      final ticket = RepairTicket.fromDynamicJson({
        'activeId': 'abc123',
        'status': '待评价',
        'createTime': '1728000000000',
        'activeTime': '2026-09-03 07:49:23',
        'content':
            '{"维修项目":"水/上下水管类","故障地点":"望江学生区/东苑五栋主楼315",'
            '"服务单位":"维修与通讯服务中心望江校区","故障描述":"冲水时水管连接处大量漏水"}',
      });
      expect(ticket.id, 'abc123');
      expect(ticket.activeId, 'abc123');
      expect(ticket.projectName, '水/上下水管类');
      expect(ticket.areaName, '望江学生区/东苑五栋主楼315');
      expect(ticket.serviceUnit, '维修与通讯服务中心望江校区');
      expect(ticket.content, '冲水时水管连接处大量漏水');
      expect(ticket.status, '待评价');
    });

    test('content 已是对象（非字符串）也能解析', () {
      // issue #273：个别工单 content 可能是后端已解析为对象
      final ticket = RepairTicket.fromDynamicJson({
        'activeId': 'obj-1',
        'content': {
          '维修项目': '水/下水疏通类',
          '故障地点': '某校区某宿舍楼',
          '服务单位': '维护中心',
          '故障描述': '下水道堵塞',
        },
      });
      expect(ticket.projectName, '水/下水疏通类');
      expect(ticket.areaName, '某校区某宿舍楼');
      expect(ticket.serviceUnit, '维护中心');
      expect(ticket.content, '下水道堵塞');
    });

    test('双层转义 JSON 字符串也能解析', () {
      // content 是字符串，内含转义的 JSON 字符串
      final inner = jsonEncodeStr({
        '维修项目': '电/室内照明类',
        '故障地点': '江安学生区/西苑八栋',
        '故障描述': '阳台灯不亮',
      });
      final ticket = RepairTicket.fromDynamicJson({
        'activeId': 'esc-1',
        'content': inner,
      });
      expect(ticket.projectName, '电/室内照明类');
      expect(ticket.areaName, '江安学生区/西苑八栋');
      expect(ticket.content, '阳台灯不亮');
    });

    test('值内含裸换行的 JSON（多行故障描述）也能解析（issue #273 实例）', () {
      // 后端拼接 content 时不转义用户输入：多行描述的裸换行让整段 JSON 非法，
      // jsonDecode 抛 "Control character in string"，此前导致卡片全字段为空
      const content =
          '{"维修项目":"水/下水疏通类",'
          '"故障地点":"江安学生区/西苑六栋5单元301C",'
          '"服务单位":"维修与通讯服务中心江安校区",'
          '"故障描述":"1. 厕所洗拖把的水池堵塞\n2.厕所洗拖把的水池水龙头滴水关不紧'
          '\n3.厕所靠门口的坑位的冲水按钮损坏，按下不回弹一直冲水"}';
      final ticket = RepairTicket.fromDynamicJson({
        'activeId': 'nl-1',
        'status': '待评价',
        'content': content,
      });
      expect(ticket.projectName, '水/下水疏通类');
      expect(ticket.areaName, '江安学生区/西苑六栋5单元301C');
      expect(ticket.serviceUnit, '维修与通讯服务中心江安校区');
      expect(ticket.content, contains('1. 厕所洗拖把的水池堵塞'));
      expect(ticket.content, contains('3.厕所靠门口的坑位的冲水按钮损坏'));
      expect(ticket.content, isNot(contains('"故障描述"'))); // 不出现原始 JSON 键
    });

    test('值内含裸回车/制表符的 JSON 也能解析', () {
      const content = '{"维修项目":"木/床柜类","故障描述":"床板异响\t翻身后更明显\r\n影响睡眠"}';
      final ticket = RepairTicket.fromDynamicJson({
        'activeId': 'cr-1',
        'content': content,
      });
      expect(ticket.projectName, '木/床柜类');
      expect(ticket.content, contains('床板异响\t翻身后更明显'));
    });

    test('解析失败不回退为原始 JSON 文本（issue #273 核心）', () {
      // 无法解析的 content：展示字段拼接或空，绝不显示原始 JSON
      final ticket = RepairTicket.fromDynamicJson({
        'activeId': 'bad-1',
        'content': '{"维修项目":"未知模板","extra":"..."}',
      });
      // 有字段时展示拼接内容
      expect(ticket.projectName, '未知模板');
      expect(ticket.content, contains('未知模板'));
      expect(ticket.content, isNot(contains('"维修项目"'))); // 不出现 JSON 键
    });

    test('content 非 JSON 纯文本时原样作为描述', () {
      final ticket = RepairTicket.fromDynamicJson({
        'activeId': 'txt-1',
        'content': '柜门坏了，请尽快维修',
      });
      expect(ticket.content, '柜门坏了，请尽快维修');
      expect(ticket.projectName, '');
    });

    test('content 缺失时各字段为空不崩溃', () {
      final ticket = RepairTicket.fromDynamicJson({
        'activeId': 'empty-1',
        'status': '已撤回',
      });
      expect(ticket.content, '');
      expect(ticket.projectName, '');
      expect(ticket.areaName, '');
      expect(ticket.status, '已撤回');
    });

    test('activeId 缺失时回退 id', () {
      final ticket = RepairTicket.fromDynamicJson({
        'id': 'fallback-id',
        'content': '{"维修项目":"木/床柜类","故障描述":"柜门倾斜"}',
      });
      expect(ticket.id, 'fallback-id');
      expect(ticket.activeId, 'fallback-id');
    });
  });
}

/// 用标准 JSON 编码（避免引号转义手写错误）。
String jsonEncodeStr(Map<String, String> map) {
  final entries = map.entries.map((e) => '"${e.key}":"${e.value}"').join(',');
  return '{$entries}';
}
