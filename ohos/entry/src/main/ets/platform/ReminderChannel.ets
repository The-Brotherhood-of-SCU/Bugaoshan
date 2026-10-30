import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { preferences } from '@kit.ArkData';
import { MethodCall, MethodResult } from '@ohos/flutter_ohos';

// Keep this budget in sync with MethodChannelReminderTransport.pendingLimit.
export const COURSE_REMINDER_LIMIT = 30;
const NOTIFICATION_BASE = 0x42000000;
const GROUP_PREFIX = 'bugaoshan.reminder.';

export class ReminderChannelError extends Error {
  channelCode: string;

  constructor(channelCode: string, message: string) {
    super(message);
    this.channelCode = channelCode;
  }
}

function invalid(message: string): ReminderChannelError {
  return new ReminderChannelError('INVALID_ARGUMENT', message);
}

function text(args: Map<string, Object>, key: string): string {
  const value = args.get(key);
  if (typeof value !== 'string') throw invalid(`Expected text: ${key}`);
  return value;
}

function millis(args: Map<string, Object>, key: string): number {
  const value = args.get(key);
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0 || value > 8640000000000000) {
    throw invalid(`Invalid timestamp: ${key}`);
  }
  return value;
}

export class CourseReminder {
  id: string;
  fireAt: number;
  title: string;
  body: string;

  constructor(value: Object) {
    if (!(value instanceof Map)) throw invalid('Expected a reminder map');
    const args = value as Map<string, Object>;
    this.id = text(args, 'id');
    this.fireAt = millis(args, 'fireAtMillis');
    this.title = text(args, 'title');
    this.body = text(args, 'body');
    if (this.id.length === 0 || text(args, 'kind') !== 'course_start') throw invalid('Invalid reminder identity or kind');
    text(args, 'collapseKey');
  }
}

/** Dart owns course recurrence, lead times, quiet hours and privacy. Only validate its final plan here. */
export function parseCourseReminderPlan(value: Object, now: number): CourseReminder[] {
  if (!(value instanceof Map)) throw invalid('Expected a reminder plan');
  const args = value as Map<string, Object>;
  if (args.get('schema') !== 1) throw invalid('Unsupported reminder plan schema');
  if (text(args, 'planId').length === 0 || text(args, 'channel') !== 'bugaoshan_reminder') {
    throw invalid('Invalid plan identity or channel');
  }
  millis(args, 'generatedAtMillis');
  const start = millis(args, 'windowStartMillis');
  const end = millis(args, 'windowEndMillis');
  if (end < start) throw invalid('Invalid reminder window');
  const list = args.get('reminders');
  if (!Array.isArray(list) || list.length > 1000) throw invalid('Invalid reminders list');
  const reminders: CourseReminder[] = [];
  const ids = new Set<string>();
  for (const value of list as Object[]) {
    const item = new CourseReminder(value);
    if (ids.has(item.id) || item.fireAt < start || item.fireAt > end) throw invalid('Invalid reminder ID or date');
    ids.add(item.id);
    if (item.fireAt > now) reminders.push(item);
  }
  if (reminders.length > COURSE_REMINDER_LIMIT) {
    throw new ReminderChannelError('REMINDER_LIMIT', 'Course reminder plan exceeds the OHOS scheduling budget');
  }
  return reminders;
}

export function isCourseReminder(request: reminderAgentManager.ReminderRequest): boolean {
  const id = request.notificationId;
  return id !== undefined && id >= NOTIFICATION_BASE && id < NOTIFICATION_BASE + COURSE_REMINDER_LIMIT &&
    request.groupId === `${GROUP_PREFIX}${id}`;
}

export function courseReminderRequest(item: CourseReminder, index: number, bundleName: string,
  closeLabel: string): reminderAgentManager.ReminderRequestCalendar {
  // Calendar agents use local wall-clock components. Round up so subsecond precision never fires early.
  const date = new Date(Math.ceil(item.fireAt / 1000) * 1000);
  const notificationId = NOTIFICATION_BASE + index;
  return {
    reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
    dateTime: {
      year: date.getFullYear(), month: date.getMonth() + 1, day: date.getDate(),
      hour: date.getHours(), minute: date.getMinutes(), second: date.getSeconds()
    },
    title: item.title,
    content: item.body,
    expiredContent: item.body,
    notificationId: notificationId,
    // Shared groups are cancelled together by OHOS. Each lead-time notification needs its own group.
    groupId: `${GROUP_PREFIX}${notificationId}`,
    wantAgent: { pkgName: bundleName, abilityName: 'EntryAbility' },
    actionButton: [{ title: closeLabel, type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }],
    slotType: notificationManager.SlotType.SERVICE_INFORMATION,
    ringDuration: 0, // Use the user's system notification sound instead of the agent alarm tone.
    snoozeTimes: 0,
    tapDismissed: true
  };
}

export class ReminderChannel {
  private queue: Promise<void> = Promise.resolve();
  private disposed: boolean = false;
  private closeLabel: string;
  private store: preferences.Preferences;
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.closeLabel = context.resourceManager.getStringSync($r('app.string.reminder_close').id);
    this.store = preferences.getPreferencesSync(context, { name: 'course_reminder_permission' });
  }

  private async permissionStatus(): Promise<string> {
    if (await notificationManager.isNotificationEnabled()) return 'authorized';
    return this.store.getSync('requested', false) === true ? 'denied' : 'notDetermined';
  }

  private async requestAuthorization(): Promise<boolean> {
    if (await notificationManager.isNotificationEnabled()) return true;
    this.store.putSync('requested', true);
    await this.store.flush();
    try {
      await notificationManager.requestEnableNotification(this.context);
    } catch (error) {
      // A dismissed/denied prompt is a normal result; propagate actual service errors.
      if ((error as BusinessError).code !== 1600004) throw error as Error;
    }
    return await notificationManager.isNotificationEnabled();
  }

  private async cancel(id: number): Promise<void> {
    try {
      await reminderAgentManager.cancelReminder(id);
    } catch (error) {
      // The user may close a reminder between listing and cancelling it.
      if ((error as BusinessError).code !== 1700003 && (error as BusinessError).code !== 1700004) throw error as Error;
    }
  }

  handle(call: MethodCall, result: MethodResult): void {
    // Full replacement, cancellation and status reads share one queue, including rollback on failure.
    this.queue = this.queue.then(async () => {
      try {
        if (this.disposed) throw new ReminderChannelError('UNSUPPORTED_PLATFORM', 'Reminder channel disposed');
        switch (call.method) {
          case 'syncPlan':
            await this.syncPlan(call.args);
            result.success(null);
            break;
          case 'cancelAll':
            await this.cancelAll();
            result.success(null);
            break;
          case 'requestAuthorization':
            result.success(await this.requestAuthorization());
            break;
          case 'getPermissionStatus':
            result.success(await this.permissionStatus());
            break;
          case 'getPendingCount':
            result.success(await this.pendingCount());
            break;
          case 'openNotificationSettings':
            await notificationManager.openNotificationSettings(this.context);
            result.success(true);
            break;
          default:
            result.notImplemented();
        }
      } catch (error) {
        if (error instanceof ReminderChannelError) {
          result.error(error.channelCode, error.message, null);
        } else {
          const code = (error as BusinessError).code;
          const channelCode = code === 1700001 ? 'NOT_AUTHORIZED' :
            code === 801 ? 'UNSUPPORTED_PLATFORM' : 'REMINDER_FAILED';
          const message = code === 1700002 ?
            'OHOS reminder quota or agent-reminder entitlement unavailable (1700002)' :
            `OHOS reminder operation failed (${code ?? 'unknown'}): ${(error as Error).message}`;
          result.error(channelCode, message, null);
        }
      }
    });
  }

  private async syncPlan(value: Object): Promise<void> {
    const reminders = parseCourseReminderPlan(value, Date.now()); // Validate before deleting any existing schedule.
    if (reminders.length === 0) {
      await this.cancelAll();
      return;
    }
    if (await this.permissionStatus() !== 'authorized') {
      throw new ReminderChannelError('NOT_AUTHORIZED', 'Notifications are disabled');
    }
    await notificationManager.addSlot(notificationManager.SlotType.SERVICE_INFORMATION);
    await this.cancelAll();
    const published: number[] = [];
    try {
      for (let index = 0; index < reminders.length; index++) {
        if (reminders[index].fireAt <= Date.now()) continue;
        published.push(await reminderAgentManager.publishReminder(courseReminderRequest(reminders[index], index,
          this.context.applicationInfo.name, this.closeLabel)));
      }
    } catch (error) {
      // Never leave a partially applied plan reported as successful. Reconciliation can retry safely.
      for (const id of published) {
        try {
          await this.cancel(id);
        } catch (rollbackError) {
          // The next full sync enumerates leftovers; do not log course titles or notification bodies.
          hilog.warn(0x0000, 'CourseReminder', 'Could not roll back a reminder: %{public}s',
            `${(rollbackError as BusinessError).code ?? 'unknown'}`);
        }
      }
      throw error as Error;
    }
  }

  private async cancelAll(): Promise<void> {
    for (const info of await reminderAgentManager.getAllValidReminders()) {
      if (isCourseReminder(info.reminderReq)) await this.cancel(info.reminderId);
    }
  }

  private async pendingCount(): Promise<number> {
    const now = Date.now();
    let count = 0;
    for (const info of await reminderAgentManager.getAllValidReminders()) {
      if (!isCourseReminder(info.reminderReq) ||
        info.reminderReq.reminderType !== reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR) continue;
      const date = (info.reminderReq as reminderAgentManager.ReminderRequestCalendar).dateTime;
      const fireAt = new Date(date.year, date.month - 1, date.day, date.hour, date.minute, date.second ?? 0).getTime();
      if (fireAt > now) count++;
    }
    return count;
  }

  dispose(): void {
    this.disposed = true;
    // System agents deliberately survive engine/process teardown.
  }
}
