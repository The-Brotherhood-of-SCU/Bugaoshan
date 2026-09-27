import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import hilog from '@ohos.hilog';
import relationalStore from '@ohos.data.relationalStore';
import { CourseSnapshot, decodeSnapshot, SnapshotCourse } from './CourseCardModel';

class StoredTime {
  hour: number = 0;
  minute: number = 0;
}

class StoredSlot {
  startTime: StoredTime = new StoredTime();
  endTime: StoredTime = new StoredTime();
}

class StoredSchedule {
  semesterStartDate: string = '';
  totalWeeks: number = 0;
  timeSlots: StoredSlot[] = [];
}

class ScheduleEntry {
  id: string = '';
  config: StoredSchedule = new StoredSchedule();
}

function validDate(value: string): boolean {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().substring(0, 10) === value;
}

function dateAfter(start: string, days: number): string {
  const date = new Date(`${start}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return `${date.getUTCFullYear()}-${(date.getUTCMonth() + 1).toString().padStart(2, '0')}-${date.getUTCDate().toString().padStart(2, '0')}`;
}

function minutes(time: StoredTime | undefined): number {
  if (!time || !Number.isInteger(time.hour) || !Number.isInteger(time.minute) ||
    time.hour < 0 || time.hour > 23 || time.minute < 0 || time.minute > 59) return -1;
  return time.hour * 60 + time.minute;
}

async function currentScheduleId(db: relationalStore.RdbStore): Promise<string> {
  const rows = await db.querySql('SELECT value FROM metadata WHERE key = ?', ['currentScheduleId']);
  try {
    return rows.goToNextRow() ? rows.getString(0) : '';
  } finally {
    rows.close();
  }
}

async function schedules(db: relationalStore.RdbStore): Promise<ScheduleEntry[]> {
  const rows = await db.querySql('SELECT id, config_json FROM schedules');
  const entries: ScheduleEntry[] = [];
  try {
    while (rows.goToNextRow()) {
      try {
        const entry = new ScheduleEntry();
        entry.id = rows.getString(0);
        entry.config = JSON.parse(rows.getString(1)) as StoredSchedule;
        if (entry.config && validDate(entry.config.semesterStartDate) &&
          Number.isInteger(entry.config.totalWeeks) && entry.config.totalWeeks > 0 &&
          entry.config.totalWeeks <= 60) entries.push(entry);
      } catch (_error) {
        // One malformed schedule must not hide the remaining schedules.
      }
    }
  } finally {
    rows.close();
  }
  return entries;
}

async function courses(db: relationalStore.RdbStore, entry: ScheduleEntry): Promise<SnapshotCourse[]> {
  const rows = await db.querySql(
    `SELECT id, COALESCE(name, ''), COALESCE(location, ''), start_week, end_week,
      day_of_week, start_section, end_section, color_value, week_type
      FROM courses WHERE schedule_id = ?`, [entry.id]);
  const courses: SnapshotCourse[] = [];
  const slots = Array.isArray(entry.config.timeSlots) ? entry.config.timeSlots : [];
  try {
    while (rows.goToNextRow()) {
      const course = new SnapshotCourse();
      course.id = rows.getString(0);
      course.name = rows.getString(1);
      course.location = rows.getString(2);
      const startWeek = rows.getLong(3);
      const endWeek = rows.getLong(4);
      course.dayOfWeek = rows.getLong(5);
      course.startSection = rows.getLong(6);
      course.endSection = rows.getLong(7);
      course.colorValue = rows.getLong(8) >>> 0;
      const weekType = rows.getLong(9);
      for (let week = Math.max(1, startWeek); week <= Math.min(entry.config.totalWeeks, endWeek); week++) {
        if (weekType === 1 && week % 2 === 0) continue;
        if (weekType === 2 && week % 2 !== 0) continue;
        course.activeWeeks.push(week);
      }
      course.startMinutes = minutes(slots[course.startSection - 1]?.startTime);
      course.endMinutes = minutes(slots[course.endSection - 1]?.endTime);
      courses.push(course);
    }
  } finally {
    rows.close();
  }
  return courses;
}

export async function loadCourseSnapshot(context: common.Context, showTomorrow: boolean): Promise<CourseSnapshot> {
  const snapshot = new CourseSnapshot();
  snapshot.showTomorrow = showTomorrow;
  const appContext = context.getApplicationContext();
  // sqflite_ohos opens this name through relationalStore's default rdb directory.
  const databasePath = `${appContext.databaseDir}/rdb/bugaoshan.db`;
  if (!fs.accessSync(databasePath)) {
    hilog.warn(0x0000, 'CourseCard', 'Course database not found: %{public}s', databasePath);
    return snapshot;
  }

  const config: relationalStore.StoreConfig = {
    name: 'bugaoshan.db',
    securityLevel: relationalStore.SecurityLevel.S1,
    tokenizer: relationalStore.Tokenizer.ICU_TOKENIZER,
    isReadOnly: true
  };
  const db = await relationalStore.getRdbStore(appContext, config);
  try {
    const entries = await schedules(db);
    if (entries.length === 0) return snapshot;
    const selectedId = await currentScheduleId(db);
    const current = entries.find((entry: ScheduleEntry) => entry.id === selectedId) ?? entries[0];
    snapshot.hasSchedule = true;
    snapshot.semesterStart = current.config.semesterStartDate;
    snapshot.totalWeeks = current.config.totalWeeks;
    const end = dateAfter(snapshot.semesterStart, snapshot.totalWeeks * 7 - 1);
    for (const entry of entries) {
      const start = entry.config.semesterStartDate;
      if (entry.id !== current.id && start > end &&
        (snapshot.nextSemesterStart === '' || start < snapshot.nextSemesterStart)) {
        snapshot.nextSemesterStart = start;
      }
    }
    snapshot.courses = await courses(db, current);
    return decodeSnapshot(JSON.stringify(snapshot));
  } finally {
    await db.close();
  }
}
