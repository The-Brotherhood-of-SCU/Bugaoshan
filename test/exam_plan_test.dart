import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';
import 'package:bugaoshan/services/ics_service.dart';

void main() {
  group('Exam plan ICS export', () {
    test('exports exams as copy payloads', () {
      const exam = ExamInfo(
        courseName: '高等数学A',
        week: '第 18 周',
        date: '2026-06-27',
        weekday: '星期六',
        timeRange: '09:00-11:00',
        location: '江安一教A101',
        seatNumber: '12',
        ticketNumber: 'SCU20260627',
        tip: '请携带学生证',
      );

      expect(exam.toJson(), {
        'courseName': '高等数学A',
        'week': '第 18 周',
        'date': '2026-06-27',
        'weekday': '星期六',
        'timeRange': '09:00-11:00',
        'location': '江安一教A101',
        'seatNumber': '12',
        'ticketNumber': 'SCU20260627',
        'tip': '请携带学生证',
      });
    });

    test('exports exams as calendar events', () {
      final ics = IcsService.genExamIcs(
        exams: const [
          ExamInfo(
            courseName: '高等数学A',
            week: '第 18 周',
            date: '2026-06-27',
            weekday: '星期六',
            timeRange: '09:00-11:00',
            location: '江安一教A101',
            seatNumber: '12',
            ticketNumber: 'SCU20260627',
            tip: '请携带学生证',
          ),
        ],
      );

      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('DTSTART;TZID=Asia/Shanghai:20260627T090000'));
      expect(ics, contains('DTEND;TZID=Asia/Shanghai:20260627T110000'));
      expect(ics, contains('SUMMARY:高等数学A考试'));
      expect(ics, contains('LOCATION:四川大学江安校区 · 江安一教A101'));
      expect(ics, contains('GEO:30.5601863;103.9973029'));
      expect(ics, contains('座位号: 12'));
    });

    test('removes finished marker from exported calendar', () {
      final ics = IcsService.genExamIcs(
        exams: const [
          ExamInfo(
            courseName: '高等数学A（已结束）',
            week: '第 18 周',
            date: '2026-06-27',
            weekday: '星期六',
            timeRange: '09:00-11:00',
            location: '江安一教A101',
            seatNumber: '12',
            ticketNumber: '',
            tip: '无',
          ),
        ],
      );

      expect(ics, contains('SUMMARY:高等数学A考试'));
      expect(ics, isNot(contains('（已结束）')));
    });

    test('exports exams as native calendar payloads', () {
      final events = IcsService.genExamCalendarEvents(
        exams: const [
          ExamInfo(
            courseName: '(107447030-31) 高等数学A（已结束）',
            week: '第 18 周',
            date: '2026-06-27',
            weekday: '星期六',
            timeRange: '09:00-11:00',
            location: '江安一教A101',
            seatNumber: '12',
            ticketNumber: 'SCU20260627',
            tip: '请携带学生证',
          ),
        ],
      );

      expect(events, hasLength(1));
      final payload = events.single.toPlatformJson();
      expect(payload['title'], '(107447030-31) 高等数学A考试');
      expect(payload['location'], '四川大学江安校区 · 江安一教A101');
      expect(payload['notes'], contains('座位号: 12'));
      expect(payload['notes'], contains('准考证号: SCU20260627'));
      expect(payload['timeZone'], 'Asia/Shanghai');
      expect(payload['structuredLocation'], {
        'title': '四川大学江安校区 · 江安一教A101',
        'latitude': 30.5601863,
        'longitude': 103.9973029,
        'radius': 250.0,
      });
      expect(payload['start'], {
        'year': 2026,
        'month': 6,
        'day': 27,
        'hour': 9,
        'minute': 0,
      });
      expect(payload['end'], {
        'year': 2026,
        'month': 6,
        'day': 27,
        'hour': 11,
        'minute': 0,
      });
    });

    test('keeps leading course sequence untouched', () {
      final ics = IcsService.genExamIcs(
        exams: const [
          ExamInfo(
            courseName: '(308085030-05) 化工原理（Ⅰ）-2',
            week: '第 17 周',
            date: '2026-06-29',
            weekday: '星期一',
            timeRange: '19:00-21:00',
            location: '江安 综合楼C座 C303',
            seatNumber: '8',
            ticketNumber: '',
            tip: '无',
          ),
        ],
      );

      expect(ics, contains('SUMMARY:(308085030-05) 化工原理（Ⅰ）-2考试'));
    });

    test('keeps exam UID stable across isPast state and finished marker', () {
      const pastExam = ExamInfo(
        courseName: '(107447030-31) 高等数学A（已结束）',
        week: '第 18 周',
        date: '2020-06-27',
        weekday: '星期六',
        timeRange: '09:00-11:00',
        location: '江安一教A101',
        seatNumber: '12',
        ticketNumber: '',
        tip: '无',
      );
      const futureExam = ExamInfo(
        courseName: '(107447030-31) 高等数学A',
        week: '第 18 周',
        date: '2099-06-28',
        weekday: '星期六',
        timeRange: '10:00-12:00',
        location: '江安一教A101',
        seatNumber: '12',
        ticketNumber: '',
        tip: '无',
      );

      expect(pastExam.isPast, isTrue);
      expect(futureExam.isPast, isFalse);

      final pastUid = IcsService.genExamCalendarEvents(
        exams: const [pastExam],
      ).single.uid;
      final futureUid = IcsService.genExamCalendarEvents(
        exams: const [futureExam],
      ).single.uid;

      expect(pastUid, futureUid);
      expect(pastUid, startsWith('exam-'));
      expect(pastUid, endsWith('@bugaoshan'));
    });

    test('builds exam calendar export payload in one place', () {
      final payload = IcsService.genExamExportPayload(
        fileName: 'exam_plan_2026-06-27_2026-06-27.ics',
        exams: const [
          ExamInfo(
            courseName: '高等数学A',
            week: '第 18 周',
            date: '2026-06-27',
            weekday: '星期六',
            timeRange: '09:00-11:00',
            location: '江安一教A101',
            seatNumber: '12',
            ticketNumber: '',
            tip: '无',
          ),
        ],
      );

      expect(payload.fileName, 'exam_plan_2026-06-27_2026-06-27.ics');
      expect(payload.icsContent, contains('SUMMARY:高等数学A考试'));
      expect(payload.events, hasLength(1));
      expect(payload.events.single['uid'], startsWith('exam-'));
    });
  });
}
