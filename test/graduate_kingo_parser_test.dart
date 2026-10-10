import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/utils/graduate_schedule_parser.dart';

/// 金智研究生系统（gsapp）课表行的字段映射测试。
///
/// 字段名来自 WakeUp课程表 的 KingoInfo 数据结构（反汇编确认）：`rkjs` 教师 /
/// `skdd` 地点 / `xq` 星期 / `jcdm`+`jsdm` 起止节次（两位零填充代码）/
/// `jcxx` 节次信息文本 / `skzs` 上课周数 / `dsz` 单双周 / `skbh` 上课编号。
/// 本科 EMAP 字段（`jsxm`/`cdmc`/`xqj`/`jcs`/`zcd`）在
/// `graduate_schedule_parser_test.dart` 已覆盖，这里只测研究生形状。
void main() {
  group('金智研究生字段（KingoInfo 形状）', () {
    test('完整行：数字星期 + 节次代码 + 周数区间', () {
      final courses = graduateCoursesFromJson([
        {
          'skbh': '2025202610001',
          'kcmc': '现代信号处理',
          'rkjs': '王五',
          'skdd': '江安A101',
          'xq': '1',
          'jcdm': '01',
          'jsdm': '02',
          'jcxx': '第1-2节',
          'skzs': '1-16',
          'dsz': '',
          'xf': '3',
        },
      ]);
      expect(courses, hasLength(1));
      final c = courses.first;
      expect(c.id, '2025202610001');
      expect(c.name, '现代信号处理');
      expect(c.teacher, '王五');
      expect(c.location, '江安A101');
      expect(c.dayOfWeek, 1);
      expect(c.startSection, 1);
      expect(c.endSection, 2);
      expect(c.startWeek, 1);
      expect(c.endWeek, 16);
      expect(c.weekType, WeekType.every);
    });

    test('中文星期文本（xq = 星期一）可解析', () {
      final courses = graduateCoursesFromJson([
        {
          'kcmc': '学术英语',
          'rkjs': '张三',
          'skdd': '望江B209',
          'xq': '星期五',
          'jcdm': '03',
          'jsdm': '04',
          'skzs': '1-16',
        },
      ]);
      expect(courses.first.dayOfWeek, 5);
    });

    test('rq 星期文本兜底（xq 缺失时）', () {
      final courses = graduateCoursesFromJson([
        {
          'kcmc': '自然辩证法',
          'rkjs': '李四',
          'skdd': '江安C305',
          'rq': '周三',
          'jcdm': '05',
          'jsdm': '06',
          'skzs': '1-16',
        },
      ]);
      expect(courses.first.dayOfWeek, 3);
    });

    test('rq 是具体日期时不会误判星期（退回默认并按区间过滤）', () {
      final courses = graduateCoursesFromJson([
        {
          'kcmc': '机器学习',
          'rkjs': '赵六',
          'skdd': '望江B209',
          'rq': '2025-09-15',
          'jcdm': '01',
          'jsdm': '02',
          'skzs': '1-16',
        },
      ]);
      // 日期文本匹配不到中文星期，dayOfWeek 退回默认 1 而不是崩溃或取错值。
      expect(courses.first.dayOfWeek, 1);
    });

    test('dsz = 单 → WeekType.odd；dsz = 双 → WeekType.even', () {
      final courses = graduateCoursesFromJson([
        {
          'kcmc': '矩阵论',
          'xq': '2',
          'jcdm': '01',
          'jsdm': '02',
          'skzs': '1-16',
          'dsz': '单',
        },
        {
          'kcmc': '随机过程',
          'xq': '4',
          'jcdm': '03',
          'jsdm': '04',
          'skzs': '1-16',
          'dsz': '双',
        },
      ]);
      expect(courses[0].weekType, WeekType.odd);
      expect(courses[1].weekType, WeekType.even);
      expect(courses[0].startWeek, 1);
      expect(courses[0].endWeek, 16);
    });

    test('skzs 连续区间端点同奇偶时不误判（dsz 才是单双周权威来源）', () {
      final courses = graduateCoursesFromJson([
        {
          'kcmc': '数值分析',
          'xq': '3',
          'jcdm': '03',
          'jsdm': '05',
          'skzs': '3-17',
          'dsz': '',
        },
      ]);
      expect(courses.first.weekType, WeekType.every);
      expect(courses.first.startWeek, 3);
      expect(courses.first.endWeek, 17);
    });

    test('jcxx 文本可独立提供节次（jcdm/jsdm 缺失时）', () {
      final courses = graduateCoursesFromJson([
        {
          'kcmc': '论文写作',
          'xq': '4',
          'jcxx': '第7-8节',
          'skzs': '9-16',
          'dsz': '双',
        },
      ]);
      final c = courses.first;
      expect(c.startSection, 7);
      expect(c.endSection, 8);
      expect(c.weekType, WeekType.even);
    });

    test('EMAP 信封包裹的金智行可被捕获解析入口识别', () {
      final payload =
          '{"code": "0", "datas": {"xskbcx": {"kbList": ['
          '{"kcmc": "现代信号处理", "rkjs": "王五", "skdd": "江安A101", '
          '"xq": "1", "jcdm": "01", "jsdm": "02", "skzs": "1-16", "dsz": ""}, '
          '{"kcmc": "学术英语", "rkjs": "张三", "skdd": "望江B209", '
          '"xq": "5", "jcdm": "03", "jsdm": "04", "skzs": "1-16", "dsz": "双"}'
          '], "totalSize": 2}}, '
          '"extParams": {"code": 1, "totalPage": 0, "logId": "abcdef"}}';
      final courses = graduateCoursesFromCapturedJson([payload]);
      expect(courses, hasLength(2));
      expect(courses.map((e) => e.name), containsAll(['现代信号处理', '学术英语']));
      expect(
        courses.firstWhere((e) => e.name == '学术英语').weekType,
        WeekType.even,
      );
    });

    test('只有课名的参数行不会被误认为课程（捕获路径过滤）', () {
      // 直接入口 graduateCoursesFromJson 信任传入的行、不做形态过滤；
      // 过滤逻辑在 WebView 捕获解析（graduateCoursesFromCapturedJson）里。
      final payload =
          '[{"kcmc": "高等数学", "kcdm": "MATH1001"}, '
          '{"CSDM": "01", "CSMC": "全日制"}]';
      expect(graduateCoursesFromCapturedJson([payload]), isEmpty);
    });
  });
}
