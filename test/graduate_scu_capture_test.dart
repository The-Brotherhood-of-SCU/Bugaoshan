import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/utils/graduate_schedule_parser.dart';

/// 川大研究生课表（ehall wdkbapp `xspkjgcx.do`）真实信封/字段形状测试。
///
/// 字段结构 2026-09-15 登录抓包实测定案（见 `.tmp/gs/findings.md` §8）：
/// 信封 `datas.<动作名>.rows`，行字段为大写 EMAP 列名（KCMC/JSXM/JASMC/
/// XQ/KSJCDM/JSJCDM/ZCMC），每行 = 一节课。数据已脱敏：
/// 课程 / 教师 / 教室均为虚构，仅保留结构与取值格式。
void main() {
  const payload =
      '{"code":"0","datas":{"xspkjgcx":{"totalSize":3,"rows":['
      '{"KCMC":"测试课程一","JSXM":"张老师","JASMC":"望江研究生楼一区204",'
      '"XQ":1,"KSJCDM":2,"JSJCDM":3,"ZCMC":"2-17周","KSSJ":855,"JSSJ":1040,"XNXQDM":"20261"},'
      '{"KCMC":"测试课程二","JSXM":"李老师","JASMC":"望江三教150",'
      '"XQ":3,"KSJCDM":5,"JSJCDM":7,"ZCMC":"1-16周(单)","XNXQDM":"20261"},'
      '{"KCMC":"测试课程三","JSXM":"王老师","JASMC":"江安楼C101",'
      '"XQ":7,"KSJCDM":1,"JSJCDM":2,"ZCMC":"3-18周","XNXQDM":"20261"}'
      ']},"extParams":{"code":1,"totalPage":0,"logId":"test"}}}';

  group('川大研究生课表行（大写 EMAP 字段）', () {
    test('信封解包 + 节次起止 + 周次文本解析', () {
      final courses = graduateCoursesFromCapturedJson([payload]);
      expect(courses, hasLength(3));

      final first = courses.firstWhere((c) => c.name == '测试课程一');
      expect(first.teacher, '张老师');
      expect(first.location, '望江研究生楼一区204');
      expect(first.dayOfWeek, 1);
      expect(first.startSection, 2);
      expect(first.endSection, 3);
      expect(first.startWeek, 2);
      expect(first.endWeek, 17);
      expect(first.weekType, WeekType.every);

      final odd = courses.firstWhere((c) => c.name == '测试课程二');
      expect(odd.dayOfWeek, 3);
      expect(odd.startSection, 5);
      expect(odd.endSection, 7);
      expect(odd.weekType, WeekType.odd);

      final sunday = courses.firstWhere((c) => c.name == '测试课程三');
      expect(sunday.dayOfWeek, 7);
      expect(sunday.startWeek, 3);
      expect(sunday.endWeek, 18);
    });
  });

  group('单双周判定', () {
    test('连续区间端点同奇偶时不误判单双周（线上回归：3-17周 被标成单周）', () {
      final payload =
          '{"code":"0","datas":{"xspkjgcx":{"rows":['
          '{"KCMC":"测试课程一","JSXM":"张老师","JASMC":"教学楼204","XQ":1,"KSJCDM":2,"JSJCDM":3,"ZCMC":"3-17周"},'
          '{"KCMC":"测试课程二","JSXM":"李老师","JASMC":"教学楼204","XQ":2,"KSJCDM":4,"JSJCDM":5,"ZCMC":"2-18周"},'
          '{"KCMC":"测试课程三","JSXM":"王老师","JASMC":"教学楼204","XQ":3,"KSJCDM":6,"JSJCDM":7,"ZCMC":"1,3,5,7"}'
          ']}}}';
      final courses = graduateCoursesFromCapturedJson([payload]);
      expect(courses, hasLength(3));
      // 两端全奇 / 全偶的连续区间是「每周上课」，不是单双周
      expect(
        courses.firstWhere((c) => c.name == '测试课程一').weekType,
        WeekType.every,
      );
      expect(
        courses.firstWhere((c) => c.name == '测试课程二').weekType,
        WeekType.every,
      );
      // 稀疏周次列表仍按奇偶规律推断
      expect(
        courses.firstWhere((c) => c.name == '测试课程三').weekType,
        WeekType.odd,
      );
    });

    test('「第3-17周」「3-17周(每周)」等变体也按连续区间处理（#329 遗留坑）', () {
      final courses = graduateCoursesFromJson([
        {'KCMC': '测试课程一', 'XQ': 1, 'KSJCDM': 2, 'JSJCDM': 3, 'ZCMC': '第3-17周'},
        {
          'KCMC': '测试课程二',
          'XQ': 2,
          'KSJCDM': 4,
          'JSJCDM': 5,
          'ZCMC': '3-17周(每周)',
        },
      ]);
      // 前缀「第」与尾注「(每周)」都不影响连续区间判定，不再掉进奇偶推断
      expect(
        courses.firstWhere((c) => c.name == '测试课程一').weekType,
        WeekType.every,
      );
      expect(
        courses.firstWhere((c) => c.name == '测试课程二').weekType,
        WeekType.every,
      );
      expect(courses.firstWhere((c) => c.name == '测试课程一').endWeek, 17);
    });
  });

  group('相邻节次合并', () {
    test('同课名同周次同地点的连续节次合并为一条', () {
      final payload =
          '{"code":"0","datas":{"xspkjgcx":{"rows":['
          '{"KCMC":"测试课程一","JSXM":"张老师","JASMC":"教学楼204","XQ":1,"KSJCDM":2,"JSJCDM":2,"ZCMC":"2-17周"},'
          '{"KCMC":"测试课程一","JSXM":"张老师","JASMC":"教学楼204","XQ":1,"KSJCDM":3,"JSJCDM":3,"ZCMC":"2-17周"},'
          '{"KCMC":"测试课程一","JSXM":"张老师","JASMC":"教学楼204","XQ":1,"KSJCDM":4,"JSJCDM":4,"ZCMC":"2-17周"}'
          ']}}}';
      final courses = graduateCoursesFromCapturedJson([payload]);
      expect(courses, hasLength(1));
      expect(courses.first.startSection, 2);
      expect(courses.first.endSection, 4);
      expect(courses.first.dayOfWeek, 1);
    });

    test('中间隔节的不合并', () {
      final payload =
          '{"code":"0","datas":{"xspkjgcx":{"rows":['
          '{"KCMC":"测试课程一","JSXM":"张老师","JASMC":"教学楼204","XQ":2,"KSJCDM":2,"JSJCDM":2,"ZCMC":"2-17周"},'
          '{"KCMC":"测试课程一","JSXM":"张老师","JASMC":"教学楼204","XQ":2,"KSJCDM":4,"JSJCDM":4,"ZCMC":"2-17周"}'
          ']}}}';
      final courses = graduateCoursesFromCapturedJson([payload]);
      expect(courses, hasLength(2));
      expect(courses.map((c) => c.startSection), [2, 4]);
    });

    test('周次或教师不同不合并（同一门课两段式上课）', () {
      final payload =
          '{"code":"0","datas":{"xspkjgcx":{"rows":['
          '{"KCMC":"测试课程一","JSXM":"张老师","JASMC":"教学楼204","XQ":2,"KSJCDM":1,"JSJCDM":2,"ZCMC":"3-7周"},'
          '{"KCMC":"测试课程一","JSXM":"李老师","JASMC":"教学楼204","XQ":2,"KSJCDM":1,"JSJCDM":2,"ZCMC":"8-14周"}'
          ']}}}';
      final courses = graduateCoursesFromCapturedJson([payload]);
      expect(courses, hasLength(2));
      expect(courses.map((c) => c.teacher), ['张老师', '李老师']);
      expect(courses.map((c) => c.startWeek), [3, 8]);
    });
  });

  group('按课程名配色', () {
    test('同名课程同色，不同课程不同色', () {
      final payload =
          '{"code":"0","datas":{"xspkjgcx":{"rows":['
          '{"KCMC":"测试课程一","JSXM":"张老师","JASMC":"教学楼204","XQ":1,"KSJCDM":2,"JSJCDM":3,"ZCMC":"2-17周"},'
          '{"KCMC":"测试课程一","JSXM":"李老师","JASMC":"教学楼204","XQ":1,"KSJCDM":2,"JSJCDM":3,"ZCMC":"8-14周"},'
          '{"KCMC":"测试课程二","JSXM":"王老师","JASMC":"教学楼305","XQ":3,"KSJCDM":5,"JSJCDM":6,"ZCMC":"1-16周"}'
          ']}}}';
      final courses = graduateCoursesFromCapturedJson([payload]);
      expect(courses, hasLength(3));
      // 两段式上课的同一门课（不同周次/教师）颜色一致
      expect(courses[0].colorValue, courses[1].colorValue);
      expect(courses[0].colorValue, isNot(courses[2].colorValue));
      expect(courses[0].colorValue, isNot(0));
    });
  });

  group('学期第 1 周周一反推（SCSKRQ + PKSJ）', () {
    test('首课即周一：第1周周一 = 首课日 − (起始周−1)×7', () {
      final start = semesterStartMondayFromFirstClassRows([
        {
          'SCSKRQ': '2026-09-14',
          'PKSJ': '3-14周 星期一[05-08节]',
          'XNXQDM': '20261',
        },
      ]);
      expect(start, DateTime(2026, 8, 31));
    });

    test('首课非周一时对齐到当周周一', () {
      final start = semesterStartMondayFromFirstClassRows([
        {'SCSKRQ': '2026-09-16', 'PKSJ': '3-13周 星期三[05-07节]'},
      ]);
      expect(start, DateTime(2026, 8, 31));
    });

    test('多行投票取众数，脏行安全忽略', () {
      final start = semesterStartMondayFromFirstClassRows([
        {'SCSKRQ': '2026-09-14', 'PKSJ': '3-14周 星期一[05-08节]'},
        {'SCSKRQ': '2026-09-16', 'PKSJ': '3-13周 星期三[05-07节]'},
        {'SCSKRQ': '不是日期', 'PKSJ': '2-5周'},
        {'PKSJ': '3-14周'},
        {'SCSKRQ': '2026-09-14'},
      ]);
      expect(start, DateTime(2026, 8, 31));
    });

    test('无有效行时返回 null', () {
      expect(semesterStartMondayFromFirstClassRows(const []), isNull);
      expect(
        semesterStartMondayFromFirstClassRows([
          {'SCSKRQ': '2026-09-14'},
        ]),
        isNull,
      );
    });
  });

  group('ZCBH 周次位串（2026-09-20 浏览器抓包字段）', () {
    test('连续周位串直接给出 every 区间（真实抓包形态）', () {
      final courses = graduateCoursesFromJson([
        {
          'KCMC': '波谱分析',
          'XQ': 2,
          'KSJCDM': 1,
          'JSJCDM': 1,
          'ZCBH': '000000011111110000000000000000',
          'ZCMC': '8-14周',
        },
      ]);
      expect(courses.first.startWeek, 8);
      expect(courses.first.endWeek, 14);
      expect(courses.first.weekType, WeekType.every);
    });

    test('单双周位串按位判定，不再依赖文本/端点推断', () {
      final courses = graduateCoursesFromJson([
        {
          'KCMC': '数值分析',
          'XQ': 1,
          'KSJCDM': 2,
          'JSJCDM': 3,
          'ZCBH': '101010101010101010101010101010',
        },
      ]);
      expect(courses.first.weekType, WeekType.odd);
      expect(courses.first.startWeek, 1);
      expect(courses.first.endWeek, 29);
    });

    test('稀疏周次位串无损表达（1/5/9 周拆成三条单周记录）', () {
      final courses = graduateCoursesFromJson([
        {
          'KCMC': '分子模拟',
          'XQ': 3,
          'KSJCDM': 5,
          'JSJCDM': 6,
          'ZCBH': '1000100010${'0' * 20}',
        },
      ]);
      expect(courses, hasLength(3));
      expect(courses.map((c) => c.startWeek), [1, 5, 9]);
      expect(courses.map((c) => c.endWeek), [1, 5, 9]);
      expect(courses.map((c) => c.weekType), everyElement(WeekType.every));
    });

    test('ZCBH 优先于 ZCMC（冲突时以位串为准）', () {
      final courses = graduateCoursesFromJson([
        {
          'KCMC': '测试课程一',
          'XQ': 1,
          'KSJCDM': 1,
          'JSJCDM': 1,
          'ZCBH': '010101010101010101010101010101',
          'ZCMC': '1-16周(单)',
        },
      ]);
      // 位串说偶周，文本说单周——位串是权威，判定偶
      expect(courses.first.weekType, WeekType.even);
      expect(courses.first.startWeek, 2);
      expect(courses.first.endWeek, 30);
    });

    test('全 0 位串视为脏数据，回退 ZCMC 文本', () {
      final courses = graduateCoursesFromJson([
        {
          'KCMC': '测试课程一',
          'XQ': 1,
          'KSJCDM': 1,
          'JSJCDM': 1,
          'ZCBH': '0' * 30,
          'ZCMC': '2-17周',
        },
      ]);
      expect(courses.first.startWeek, 2);
      expect(courses.first.endWeek, 17);
      expect(courses.first.weekType, WeekType.every);
    });
  });

  group('接口精确时刻（KSSJ / JSSJ）', () {
    List<TimeSlot> derived(List<Map<String, dynamic>> rows) =>
        graduateTimeSlotsFromRows(
          rows,
          fallback: ScheduleConfig.wangJiangHuaXiTimeSlots,
        )!;

    test('按行内时刻生成专属时间表，未观测节次用预置补齐', () {
      final slots = derived([
        {'XQ': 1, 'KSJCDM': 2, 'JSJCDM': 3, 'KSSJ': 855, 'JSSJ': 1045},
        {'XQ': 3, 'KSJCDM': 5, 'JSJCDM': 7, 'KSSJ': 1400, 'JSSJ': 1635},
      ]);
      expect(slots, hasLength(12));
      // 第 1 节未观测 → 预置 8:00-8:45
      expect(slots[0].startTime, const TimeOfDay(hour: 8, minute: 0));
      expect(slots[0].endTime, const TimeOfDay(hour: 8, minute: 45));
      // 第 2 节只观测到起点 8:55，终点仍用预置 9:40
      expect(slots[1].startTime, const TimeOfDay(hour: 8, minute: 55));
      expect(slots[1].endTime, const TimeOfDay(hour: 9, minute: 40));
      // 第 3 节只观测到终点 10:45，起点仍用预置 10:00
      expect(slots[2].startTime, const TimeOfDay(hour: 10, minute: 0));
      expect(slots[2].endTime, const TimeOfDay(hour: 10, minute: 45));
      // 第 5 节起点观测 14:00，第 7 节终点观测 16:35
      expect(slots[4].startTime, const TimeOfDay(hour: 14, minute: 0));
      expect(slots[6].endTime, const TimeOfDay(hour: 16, minute: 35));
      // 第 10 节未观测 → 预置 19:30-20:15
      expect(slots[9].startTime, const TimeOfDay(hour: 19, minute: 30));
      expect(slots[9].endTime, const TimeOfDay(hour: 20, minute: 15));
    });

    test('同一节次多行观测投票取众数', () {
      final slots = derived([
        {'KSJCDM': 1, 'JSJCDM': 1, 'KSSJ': 800, 'JSSJ': 845},
        {'KSJCDM': 1, 'JSJCDM': 1, 'KSSJ': 800, 'JSSJ': 845},
        {'KSJCDM': 1, 'JSJCDM': 1, 'KSSJ': 830, 'JSSJ': 845},
      ]);
      // 800 两票压过 830 一票
      expect(slots[0].startTime, const TimeOfDay(hour: 8, minute: 0));
      expect(slots[0].endTime, const TimeOfDay(hour: 8, minute: 45));
    });

    test('脏时刻（分钟位/小时位越界）被忽略：任一侧非法则整节回退预置', () {
      final slots = derived([
        // 880 → 分钟位 80 非法：该节起点未观测，整节回退预置 8:00-8:45
        // （不混用「预置起点 + 观测终点」两种来源）
        {'KSJCDM': 1, 'JSJCDM': 1, 'KSSJ': 880, 'JSSJ': 930},
        // 合法行正常采用
        {'KSJCDM': 2, 'JSJCDM': 2, 'KSSJ': 855, 'JSSJ': 940},
      ]);
      expect(slots[0].startTime, const TimeOfDay(hour: 8, minute: 0));
      expect(slots[0].endTime, const TimeOfDay(hour: 8, minute: 45));
      expect(slots[1].startTime, const TimeOfDay(hour: 8, minute: 55));
      expect(slots[1].endTime, const TimeOfDay(hour: 9, minute: 40));
    });

    test('没有任何可用时刻时返回 null', () {
      expect(
        graduateTimeSlotsFromRows(const [
          {'XQ': 1},
        ], fallback: ScheduleConfig.wangJiangHuaXiTimeSlots),
        isNull,
      );
    });
  });
}
