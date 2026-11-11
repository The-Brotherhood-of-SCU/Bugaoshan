import { describe, it, expect } from '@ohos/hypium';
import {
  activeCourseWeeks, CourseSnapshot, dateSerial, decodeSnapshot, makeCardView, semesterEnd, SnapshotCourse
} from '../../../main/ets/cards/CourseCardModel';

function schedule(): CourseSnapshot {
  const snapshot = new CourseSnapshot();
  snapshot.hasSchedule = true;
  snapshot.semesterStart = '2026-08-31';
  snapshot.totalWeeks = 20;
  snapshot.nextSemesterStart = '2027-02-22';
  const course = new SnapshotCourse();
  course.id = 'sunday';
  course.name = 'Course';
  course.dayOfWeek = 7;
  course.activeWeeks = [4];
  course.startMinutes = 540;
  course.endMinutes = 600;
  snapshot.courses = [course];
  return snapshot;
}

export default function courseCardTest() {
  describe('CourseCard', () => {
    it('custom_weeks_override_range_and_parity', 0, () => {
      expect(activeCourseWeeks('2,4,4,8', 1, 3, 1, 6).join(',')).assertEqual('2,4');
      expect(activeCourseWeeks('8', 1, 3, 0, 6).length).assertEqual(0);
    });

    it('invalid_custom_weeks_use_existing_range_rules', 0, () => {
      expect(activeCourseWeeks('bad,0,61', 2, 6, 1, 20).join(',')).assertEqual('3,5');
      expect(activeCourseWeeks('', 1, 6, 2, 20).join(',')).assertEqual('2,4,6');
    });

    it('sunday_starts_the_new_teaching_week', 0, () => {
      const view = makeCardView(schedule(), 'en', new Date(2026, 8, 20, 8));
      expect(view.date.includes('Week 4')).assertTrue();
      expect(view.courses.length).assertEqual(1);
    });

    it('saturday_preview_uses_sunday_week', 0, () => {
      const snapshot = schedule();
      snapshot.showTomorrow = true;
      const view = makeCardView(snapshot, 'en', new Date(2026, 8, 19, 20));
      expect(view.tomorrow).assertTrue();
      expect(view.courses.length).assertEqual(1);
    });

    it('semester_ends_on_saturday_and_vacation_starts_on_sunday', 0, () => {
      const snapshot = schedule();
      expect(semesterEnd(snapshot.semesterStart, 20)).assertEqual(dateSerial(new Date(2027, 0, 16)));
      const saturday = makeCardView(snapshot, 'en', new Date(2027, 0, 16, 8));
      const sunday = makeCardView(snapshot, 'en', new Date(2027, 0, 17, 8));
      const nextSemester = makeCardView(snapshot, 'en', new Date(2027, 1, 22, 8));
      expect(saturday.date.includes('On vacation')).assertFalse();
      expect(sunday.date.includes('On vacation')).assertTrue();
      expect(nextSemester.date.includes('On vacation')).assertFalse();
    });

    it('next_semester_can_start_on_the_corrected_boundary', 0, () => {
      const snapshot = schedule();
      snapshot.nextSemesterStart = '2027-01-17';
      expect(decodeSnapshot(JSON.stringify(snapshot)).nextSemesterStart).assertEqual('2027-01-17');
    });

    it('appearance_reaches_the_card_view', 0, () => {
      const snapshot = schedule();
      snapshot.monochrome = true;
      snapshot.compact = true;
      const view = makeCardView(snapshot, 'en', new Date(2026, 8, 20, 8));
      expect(view.monochrome).assertTrue();
      expect(view.compact).assertTrue();
    });
  });
}
