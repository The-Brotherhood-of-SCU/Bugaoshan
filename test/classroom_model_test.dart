import 'package:bugaoshan/pages/campus/models/classroom_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClassroomQueryResult.periodStatusMap', () {
    test('expands continuing periods without mixing classrooms', () {
      final result = ClassroomQueryResult(
        classrooms: const [],
        classroomTime: [
          _timeSlot(
            classroomNumber: 'A101',
            sessionStart: 1,
            continuingSession: 2,
            occupancyModuleId: '06',
          ),
          _timeSlot(
            classroomNumber: 'B202',
            sessionStart: 1,
            continuingSession: 1,
            occupancyModuleId: '07',
          ),
        ],
        date: '2026-07-14',
        jxzc: 20,
      );

      expect(result.periodStatusMap('A101'), {
        1: ClassroomPeriodStatus.inClass,
        2: ClassroomPeriodStatus.inClass,
      });
      expect(result.periodStatusMap('B202'), {1: ClassroomPeriodStatus.exam});
    });

    test('treats non-positive continuing periods as one period', () {
      for (final invalidDuration in [0, -1]) {
        final statusMap = classroomPeriodStatusMap([
          _timeSlot(
            classroomNumber: 'A101',
            sessionStart: 5,
            continuingSession: invalidDuration,
            occupancyModuleId: 'room',
          ),
        ]);

        expect(statusMap, {
          5: ClassroomPeriodStatus.borrowed,
        }, reason: 'continuingsession=$invalidDuration');
      }
    });
  });
}

ClassroomTimeSlot _timeSlot({
  required String classroomNumber,
  required int sessionStart,
  required int continuingSession,
  required String occupancyModuleId,
}) {
  return ClassroomTimeSlot(
    campusNumber: '01',
    teachingBuildingNumber: '01',
    classroomNumber: classroomNumber,
    xq: 1,
    sessionstart: sessionStart,
    continuingsession: continuingSession,
    timestatenumber: '',
    occupancymoduleId: occupancyModuleId,
  );
}
