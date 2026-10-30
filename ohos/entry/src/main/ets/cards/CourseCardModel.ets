// Pure display types/calculation; safe to import from the restricted form renderer.
export class SnapshotCourse {
  id: string = '';
  name: string = '';
  location: string = '';
  dayOfWeek: number = 1;
  activeWeeks: number[] = [];
  startSection: number = 0;
  endSection: number = 0;
  startMinutes: number = -1;
  endMinutes: number = -1;
  colorValue: number = 0;
}

export class CourseSnapshot {
  schemaVersion: number = 1;
  hasSchedule: boolean = false;
  language: string = '';
  semesterStart: string = '';
  totalWeeks: number = 20;
  nextSemesterStart: string = '';
  showTomorrow: boolean = false;
  monochrome: boolean = false;
  compact: boolean = false;
  courses: SnapshotCourse[] = [];
}

export class CardCourse {
  id: string = '';
  name: string = '';
  location: string = '';
  startTime: string = '--:--';
  endTime: string = '--:--';
  section: string = '';
  color: string = '#FF2196F3';
  inProgress: boolean = false;
}

export class CardView {
  title: string = '';
  date: string = '';
  emptyText: string = '';
  tomorrow: boolean = false;
  monochrome: boolean = false;
  compact: boolean = false;
  courses: CardCourse[] = [];
}

export class CardBinding {
  model: CardView;

  constructor(model: CardView) {
    this.model = model;
  }
}

function integer(value: number, min: number, max: number): boolean {
  return Number.isInteger(value) && value >= min && value <= max;
}

function textField(value: string, max: number): boolean {
  return typeof value === 'string' && value.length <= max;
}

// Day serials use local calendar components, not elapsed 24-hour intervals (DST).
export function dateSerial(date: Date): number {
  return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / 86400000;
}

function parseDate(value: string): number {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return NaN;
  const fields = value.split('-');
  const year = Number(fields[0]);
  const month = Number(fields[1]);
  const day = Number(fields[2]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day || year < 1970 || year > 9999) return NaN;
  return date.getTime() / 86400000;
}

function weekAnchor(start: string): number {
  const day = parseDate(start);
  return day - new Date(day * 86400000).getUTCDay();
}

export function semesterEnd(start: string, totalWeeks: number): number {
  return weekAnchor(start) + totalWeeks * 7 - 1;
}

// Discrete weeks take precedence over both the range and odd/even rules, as in Dart.
export function activeCourseWeeks(custom: string, start: number, end: number,
  weekType: number, totalWeeks: number): number[] {
  const selected = custom.split(',').map((value: string) => Number(value.trim()))
    .filter((week: number) => integer(week, 1, 60));
  const weeks: number[] = [];
  for (let week = 1; week <= totalWeeks; week++) {
    if (selected.length > 0 ? selected.includes(week) :
      week >= start && week <= end && (weekType !== 1 || week % 2 === 1) &&
        (weekType !== 2 || week % 2 === 0)) weeks.push(week);
  }
  return weeks;
}

export function decodeSnapshot(json: string): CourseSnapshot {
  const snapshot = JSON.parse(json) as CourseSnapshot;
  if (!snapshot || snapshot.schemaVersion !== 1 ||
    typeof snapshot.hasSchedule !== 'boolean' || typeof snapshot.showTomorrow !== 'boolean' ||
    !textField(snapshot.language, 32) || !Array.isArray(snapshot.courses) ||
    snapshot.courses.length > 5000) throw new Error('Invalid course snapshot');
  if (!snapshot.hasSchedule) {
    const empty = new CourseSnapshot();
    empty.language = snapshot.language;
    return empty;
  }
  if (!integer(snapshot.totalWeeks, 1, 60) || !Number.isFinite(parseDate(snapshot.semesterStart)) ||
    (snapshot.nextSemesterStart !== '' &&
      (!Number.isFinite(parseDate(snapshot.nextSemesterStart)) ||
        parseDate(snapshot.nextSemesterStart) <= semesterEnd(snapshot.semesterStart, snapshot.totalWeeks)))) {
    throw new Error('Invalid semester metadata');
  }
  for (const course of snapshot.courses) {
    if (!course || !textField(course.id, 256) || !textField(course.name, 1024) ||
      !textField(course.location, 1024) || !integer(course.dayOfWeek, 1, 7) ||
      !Array.isArray(course.activeWeeks) || course.activeWeeks.length > 60 ||
      !course.activeWeeks.every((week: number) => integer(week, 1, snapshot.totalWeeks)) ||
      !integer(course.startMinutes, -1, 1439) || !integer(course.endMinutes, -1, 1439) ||
      !integer(course.startSection, 0, 1000) || !integer(course.endSection, 0, 1000) ||
      !integer(course.colorValue, 0, 4294967295)) throw new Error('Invalid course display data');
  }
  return snapshot;
}

function weekFor(snapshot: CourseSnapshot, day: number): number {
  return Math.max(1, Math.min(snapshot.totalWeeks,
    Math.floor((day - weekAnchor(snapshot.semesterStart)) / 7) + 1));
}

function coursesFor(snapshot: CourseSnapshot, date: Date): SnapshotCourse[] {
  const week = weekFor(snapshot, dateSerial(date));
  const weekday = date.getDay() === 0 ? 7 : date.getDay();
  return snapshot.courses.filter((course: SnapshotCourse) =>
    course.dayOfWeek === weekday && course.activeWeeks.includes(week))
    .sort((a: SnapshotCourse, b: SnapshotCourse) => a.startSection - b.startSection);
}

function timeText(minutes: number): string {
  if (minutes < 0) return '--:--';
  return `${Math.floor(minutes / 60).toString().padStart(2, '0')}:${(minutes % 60).toString().padStart(2, '0')}`;
}

export function makeCardView(snapshot: CourseSnapshot, systemLanguage: string, now: Date = new Date()): CardView {
  const chinese = (snapshot.language || systemLanguage).toLowerCase().startsWith('zh');
  const view = new CardView();
  view.monochrome = snapshot.monochrome;
  view.compact = snapshot.compact;
  view.title = chinese ? '不高山上' : 'Bugaoshan';
  if (!snapshot.hasSchedule) {
    view.emptyText = chinese ? '打开 App 同步课表' : 'Open the app to sync your schedule';
    return view;
  }
  const today = dateSerial(now);
  const vacation = today > semesterEnd(snapshot.semesterStart, snapshot.totalWeeks) &&
    Number.isFinite(parseDate(snapshot.nextSemesterStart)) && today < parseDate(snapshot.nextSemesterStart);
  const minutes = now.getHours() * 60 + now.getMinutes();
  const todayCourses = vacation ? [] : coursesFor(snapshot, now);
  let selected = todayCourses.filter((course: SnapshotCourse) =>
    course.endMinutes < 0 || minutes < course.endMinutes);
  const displayDate = new Date(now.getTime());
  if (!vacation && selected.length === 0 && snapshot.showTomorrow) {
    view.tomorrow = true;
    displayDate.setDate(displayDate.getDate() + 1);
    selected = coursesFor(snapshot, displayDate);
  }
  const weekdays = chinese ? ['周日', '周一', '周二', '周三', '周四', '周五', '周六'] :
    ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const week = weekFor(snapshot, dateSerial(displayDate));
  const weekText = vacation ? (chinese ? '放假中' : 'On vacation') : (chinese ? `第${week}周` : `Week ${week}`);
  const tomorrowText = view.tomorrow ? (chinese ? ' 明天' : ' Tomorrow') : '';
  view.date = `${displayDate.getMonth() + 1}/${displayDate.getDate()} ${weekdays[displayDate.getDay()]}${tomorrowText}  ${weekText}`;
  if (vacation) view.emptyText = chinese ? '享受假期～' : 'Enjoy your vacation';
  else if (view.tomorrow) view.emptyText = chinese ? '明天没课' : 'No classes tomorrow';
  else if (todayCourses.length > 0) view.emptyText = chinese ? '今天的课都上完啦' : 'All classes are finished';
  else view.emptyText = chinese ? '今天没有课程' : 'No classes today';
  view.courses = selected.map((source: SnapshotCourse, index: number) => {
    const course = new CardCourse();
    course.id = `${source.id}:${index}`;
    course.name = source.name;
    course.location = source.location;
    course.startTime = timeText(source.startMinutes);
    course.endTime = timeText(source.endMinutes);
    if (source.startSection > 0) {
      const range = source.startSection === source.endSection ? `${source.startSection}` :
        `${source.startSection}-${source.endSection}`;
      course.section = chinese ? `第${range}节` :
        `${source.startSection === source.endSection ? 'Section' : 'Sections'} ${range}`;
    }
    if (source.colorValue >= 0x01000000) {
      course.color = `#${source.colorValue.toString(16).padStart(8, '0')}`;
    }
    course.inProgress = !view.tomorrow && source.startMinutes >= 0 && source.endMinutes >= 0 &&
      minutes >= source.startMinutes && minutes < source.endMinutes;
    return course;
  });
  return view;
}

// A system request, not a promise of exact background execution.
export function nextRefreshMinutes(snapshot: CourseSnapshot, now: Date = new Date()): number {
  let next = 1440 - now.getHours() * 60 - now.getMinutes();
  if (snapshot.hasSchedule) {
    const minutes = now.getHours() * 60 + now.getMinutes();
    for (const course of coursesFor(snapshot, now)) {
      if (course.startMinutes > minutes) next = Math.min(next, course.startMinutes - minutes);
      if (course.endMinutes > minutes) next = Math.min(next, course.endMinutes - minutes);
    }
  }
  return Math.max(5, Math.min(30, Math.ceil(next)));
}
