import { describe, it, expect } from '@ohos/hypium';
import {
  COURSE_REMINDER_LIMIT, CourseReminder, courseReminderRequest, isCourseReminder, parseCourseReminderPlan
} from '../../../main/ets/platform/ReminderChannel';
import { CourseLiveState } from '../../../main/ets/platform/LiveActivityChannel';

function reminder(id: string, fireAt: number): Map<string, Object> {
  const args = new Map<string, Object>();
  args.set('id', id);
  args.set('kind', 'course_start');
  args.set('fireAtMillis', fireAt);
  args.set('title', 'Course');
  args.set('body', '08:00 · classroom');
  args.set('collapseKey', 'same-course');
  return args;
}

function plan(items: Map<string, Object>[], now: number): Map<string, Object> {
  const args = new Map<string, Object>();
  args.set('schema', 1);
  args.set('planId', 'plan');
  args.set('generatedAtMillis', now);
  args.set('windowStartMillis', now - 60000);
  args.set('windowEndMillis', now + 86400000);
  args.set('channel', 'bugaoshan_reminder');
  args.set('reminders', items);
  return args;
}

function course(now: number): Map<string, Object> {
  const args = new Map<string, Object>();
  args.set('courseName', 'Mathematics');
  args.set('location', 'A101');
  args.set('startAtMillis', now - 60000);
  args.set('endAtMillis', now + 3600000);
  args.set('nextCourseName', 'Physics');
  args.set('nextLocation', 'B202');
  return args;
}

function rejects(action: () => void): boolean {
  try { action(); } catch (_error) { return true; }
  return false;
}

export default function courseNotificationsTest() {
  describe('CourseNotificationPayloads', () => {
    it('keeps Dart ordering and text while excluding expired reminders', 0, () => {
      const now = Date.now();
      const items = parseCourseReminderPlan(plan([
        reminder('expired', now - 1000), reminder('first', now + 60000), reminder('later', now + 120000)
      ], now), now);
      expect(items.length).assertEqual(2);
      expect(items[0].id).assertEqual('first');
      expect(items[0].body).assertEqual('08:00 · classroom');
    });

    it('rejects duplicate IDs and unsupported schemas before applying a plan', 0, () => {
      const now = Date.now();
      const args = plan([reminder('same', now + 60000), reminder('same', now + 120000)], now);
      expect(rejects(() => { parseCourseReminderPlan(args, now); })).assertTrue();
      args.set('reminders', [reminder('one', now + 60000)]);
      args.set('schema', 2);
      expect(rejects(() => { parseCourseReminderPlan(args, now); })).assertTrue();
      args.set('schema', 1);
      args.set('windowEndMillis', now);
      expect(rejects(() => { parseCourseReminderPlan(args, now); })).assertTrue();
    });

    it('rejects plans exceeding the native scheduling budget', 0, () => {
      const now = Date.now();
      const items: Map<string, Object>[] = [];
      for (let index = 0; index <= COURSE_REMINDER_LIMIT; index++) {
        items.push(reminder(index.toString(), now + 60000));
      }
      expect(rejects(() => { parseCourseReminderPlan(plan(items, now), now); })).assertTrue();
    });

    it('gives separate lead times independent notification groups and preserves calendar seconds', 0, () => {
      const fireAt = new Date(2026, 9, 15, 8, 0, 15).getTime();
      const first = courseReminderRequest(new CourseReminder(reminder('lead15', fireAt)), 0, 'test.app', 'Close');
      const second = courseReminderRequest(new CourseReminder(reminder('lead5', fireAt + 600000)), 1, 'test.app', 'Close');
      expect(first.notificationId === second.notificationId).assertFalse();
      expect(first.groupId === second.groupId).assertFalse();
      expect(first.dateTime.second).assertEqual(15);
      expect(isCourseReminder(first)).assertTrue();
      first.groupId = 'unrelated';
      expect(isCourseReminder(first)).assertFalse();
    });

    it('merges activity updates and clears location and next-course text', 0, () => {
      const now = Date.now();
      const current = new CourseLiveState(course(now), null, now);
      const patch = new Map<string, Object>();
      patch.set('location', '');
      patch.set('nextCourseName', '');
      patch.set('nextLocation', '');
      const updated = new CourseLiveState(patch, current, now);
      expect(updated.courseName).assertEqual('Mathematics');
      expect(updated.endAt).assertEqual(current.endAt);
      expect(updated.location).assertEqual('');
      expect(updated.nextCourseName).assertEqual('');
      expect(updated.nextLocation).assertEqual('');
    });

    it('rejects expired and overlong activity intervals', 0, () => {
      const now = Date.now();
      const args = course(now);
      args.set('endAtMillis', now - 1000);
      expect(rejects(() => { new CourseLiveState(args, null, now); })).assertTrue();
      args.set('endAtMillis', now + 9 * 3600000);
      expect(rejects(() => { new CourseLiveState(args, null, now); })).assertTrue();
    });
  });
}
