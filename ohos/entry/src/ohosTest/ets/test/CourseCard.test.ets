import { describe, it, expect } from '@ohos/hypium';
import {
  activeCourseWeeks, CourseSnapshot, dateSerial, decodeSnapshot, makeCardView, nextRefreshMinutes, semesterEnd, SnapshotCourse
} from '../../../main/ets/cards/CourseCardModel';

function schedule(dayOfWeek: number = 7, activeWeeks: number[] = [4]): CourseSnapshot {
  const snapshot = new CourseSnapshot();
  snapshot.hasSchedule = true;
  snapshot.semesterStart = '2026-08-31';
  snapshot.totalWeeks = 20;
  snapshot.nextSemesterStart = '2027-02-22';
  const course = new SnapshotCourse();
  course.id = 'course';
  course.name = 'Course';
  course.dayOfWeek = dayOfWeek;
  course.activeWeeks = activeWeeks;
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
      const snapshot = schedule(6, [20]);
      expect(semesterEnd(snapshot.semesterStart, 20)).assertEqual(dateSerial(new Date(2027, 0, 16)));
      const saturday = makeCardView(snapshot, 'en', new Date(2027, 0, 16, 8));
      const sunday = makeCardView(snapshot, 'en', new Date(2027, 0, 17, 8));
      expect(saturday.date.includes('Week 20')).assertTrue();
      expect(saturday.courses.length).assertEqual(1);
      expect(sunday.date.includes('On vacation')).assertTrue();
      expect(sunday.courses.length).assertEqual(0);
      expect(nextRefreshMinutes(snapshot, new Date(2027, 0, 23, 8, 50))).assertEqual(30);
    });

    it('no_courses_before_the_actual_semester_start', 0, () => {
      const snapshot = schedule(1, [1]);
      snapshot.nextSemesterStart = '';
      snapshot.showTomorrow = true;
      const before = makeCardView(snapshot, 'zh', new Date(2026, 7, 24, 8));
      expect(before.courses.length).assertEqual(0);
      expect(before.tomorrow).assertFalse();
      expect(before.date.includes('未开学')).assertTrue();

      const sunday = makeCardView(schedule(7, [1]), 'zh', new Date(2026, 7, 30, 8));
      expect(sunday.courses.length).assertEqual(0);
      expect(sunday.date.includes('未开学')).assertTrue();

      const firstDay = new Date(2026, 7, 31, 8, 50);
      expect(makeCardView(snapshot, 'zh', firstDay).courses.length).assertEqual(1);
      expect(nextRefreshMinutes(snapshot, firstDay)).assertEqual(10);
    });

    it('vacation_without_a_next_schedule_has_no_courses_or_extra_refresh', 0, () => {
      const snapshot = schedule(1, [20]);
      snapshot.nextSemesterStart = '';
      const now = new Date(2027, 0, 25, 8, 50);
      const view = makeCardView(snapshot, 'zh', now);
      expect(view.courses.length).assertEqual(0);
      expect(view.date.includes('放假中')).assertTrue();
      expect(nextRefreshMinutes(snapshot, now)).assertEqual(30);
    });

    it('tomorrow_preview_can_show_the_first_day_of_vacation', 0, () => {
      const snapshot = schedule(7, [20]);
      snapshot.nextSemesterStart = '';
      snapshot.showTomorrow = true;
      const view = makeCardView(snapshot, 'zh', new Date(2027, 0, 16, 20));
      expect(view.courses.length).assertEqual(0);
      expect(view.tomorrow).assertTrue();
      expect(view.date).assertEqual('1/17 周日 明天  放假中');
    });

    it('next_semester_start_does_not_show_courses_from_the_previous_schedule', 0, () => {
      const snapshot = schedule(1, [20]);
      const now = new Date(2027, 1, 22, 8, 50);
      const view = makeCardView(snapshot, 'zh', now);
      expect(view.courses.length).assertEqual(0);
      expect(view.date.includes('新学期')).assertTrue();
      expect(view.emptyText).assertEqual('打开 App 切换到新学期课表');
      expect(nextRefreshMinutes(snapshot, now)).assertEqual(30);
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
