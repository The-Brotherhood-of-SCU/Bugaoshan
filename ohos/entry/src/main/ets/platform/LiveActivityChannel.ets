import { common, wantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { liveViewManager } from '@kit.LiveViewKit';
import { MethodCall, MethodResult } from '@ohos/flutter_ohos';

export const COURSE_LIVE_VIEW_ID = 42001;
const TIMER_PLACEHOLDER = '${placeholder.timer}';

export class LiveActivityChannelError extends Error {
  channelCode: string;

  constructor(code: string, message: string) {
    super(message);
    this.channelCode = code;
  }
}

/** Values are merged only for update; a new start must never inherit a previous course. */
export class CourseLiveState {
  courseName: string;
  location: string;
  nextCourseName: string;
  nextLocation: string;
  startAt: number;
  endAt: number;

  constructor(value: Object, previous: CourseLiveState | null = null, now: number = Date.now()) {
    if (!(value instanceof Map)) throw new LiveActivityChannelError('INVALID_ARGUMENT', 'Expected course activity data');
    const args = value as Map<string, Object>;
    this.courseName = CourseLiveState.text(args, 'courseName', previous?.courseName);
    this.location = CourseLiveState.text(args, 'location', previous?.location);
    this.nextCourseName = CourseLiveState.text(args, 'nextCourseName', previous?.nextCourseName ?? '');
    this.nextLocation = CourseLiveState.text(args, 'nextLocation', previous?.nextLocation ?? '');
    this.startAt = CourseLiveState.millis(args, 'startAtMillis', previous?.startAt ?? now);
    this.endAt = CourseLiveState.millis(args, 'endAtMillis', previous?.endAt);
    if (this.courseName.trim().length === 0 || this.endAt <= now || this.endAt <= this.startAt ||
      this.startAt > now || this.endAt - this.startAt > 8 * 60 * 60 * 1000) {
      throw new LiveActivityChannelError('INVALID_ARGUMENT', 'Expected an ongoing course of at most eight hours');
    }
  }

  private static text(args: Map<string, Object>, key: string, fallback?: string): string {
    if (!args.has(key) && fallback !== undefined) return fallback;
    const value = args.get(key);
    if (typeof value !== 'string') throw new LiveActivityChannelError('INVALID_ARGUMENT', `Expected text: ${key}`);
    return value;
  }

  private static millis(args: Map<string, Object>, key: string, fallback?: number): number {
    if (!args.has(key) && fallback !== undefined) return fallback;
    const value = args.get(key);
    if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0 || value > 8640000000000000) {
      throw new LiveActivityChannelError('INVALID_ARGUMENT', `Invalid timestamp: ${key}`);
    }
    return value;
  }
}

function checkLiveViewResult(result: liveViewManager.LiveViewResult): void {
  if (result.resultCode !== 0) {
    const error = new Error(`Live View rejected the operation (${result.resultCode}): ${result.message}`) as BusinessError;
    error.code = result.resultCode;
    throw error as Error;
  }
}

export class LiveActivityChannel {
  private context: common.UIAbilityContext;
  private remainingLabel: string;
  private nextLabel: string;
  private endedLabel: string;
  private queue: Promise<void> = Promise.resolve();
  private state: CourseLiveState | null = null;
  private foreground: boolean = false;
  private disposed: boolean = false;
  private endTimer: number = -1;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.remainingLabel = context.resourceManager.getStringSync($r('app.string.live_course_remaining').id);
    this.nextLabel = context.resourceManager.getStringSync($r('app.string.live_course_next').id);
    this.endedLabel = context.resourceManager.getStringSync($r('app.string.live_course_ended').id);
  }

  private async isEnabled(): Promise<boolean> {
    return canIUse('SystemCapability.LiveView.LiveViewService') && await liveViewManager.isLiveViewEnabled();
  }

  private async active(): Promise<liveViewManager.LiveView | null> {
    try {
      return await liveViewManager.getActiveLiveView(COURSE_LIVE_VIEW_ID);
    } catch (error) {
      if ((error as BusinessError).code === 1003500009 || (error as BusinessError).code === 1003500010) return null;
      throw error as Error;
    }
  }

  setForeground(value: boolean): void {
    this.foreground = value;
  }

  handle(call: MethodCall, result: MethodResult): void {
    this.queue = this.queue.then(async () => {
      try {
        if (this.disposed) throw new LiveActivityChannelError('UNSUPPORTED_PLATFORM', 'Live View channel disposed');
        switch (call.method) {
          case 'isSupported':
            result.success(await this.isEnabled());
            break;
          case 'start':
            result.success(await this.start(call.args));
            break;
          case 'update':
            await this.update(call.args);
            result.success(null);
            break;
          case 'end':
            await this.end();
            result.success(null);
            break;
          default:
            result.notImplemented();
        }
      } catch (error) {
        if (error instanceof LiveActivityChannelError) {
          result.error(error.channelCode, error.message, null);
        } else {
          const code = (error as BusinessError).code;
          const channelCode = code === 1003500004 ? 'NOT_AUTHORIZED' :
            code === 1003500009 || code === 1003500010 ? 'NO_ACTIVE_ACTIVITY' :
            code === 801 ? 'UNSUPPORTED_PLATFORM' : 'LIVE_VIEW_FAILED';
          const message = code === 1003500005 ?
            'The app needs Huawei Live View entitlement for the TIMER scenario (1003500005)' :
            `OHOS Live View operation failed (${code ?? 'unknown'}): ${(error as Error).message}`;
          result.error(channelCode, message, null);
        }
      }
    });
  }

  private async start(value: Object): Promise<string> {
    const state = new CourseLiveState(value);
    if (!this.foreground) throw new LiveActivityChannelError('NOT_IN_FOREGROUND', 'Live View must start in the foreground');
    await this.requireEnabled();
    const active = await this.active();
    const view = await this.buildView(state, (active?.sequence ?? 0) + 1);
    if (this.disposed || !this.foreground) {
      throw new LiveActivityChannelError('NOT_IN_FOREGROUND', 'Live View must start in the foreground');
    }
    // Recover the app-owned ID after a process/engine restart instead of creating a duplicate.
    checkLiveViewResult(active !== null ? await liveViewManager.updateLiveView(view) :
      await liveViewManager.startLiveView(view));
    if (!this.disposed) {
      this.state = state;
      this.scheduleEnd(state.endAt);
    }
    return `${COURSE_LIVE_VIEW_ID}`;
  }

  private async update(value: Object): Promise<void> {
    await this.requireEnabled();
    const fullCourse = value instanceof Map && (value as Map<string, Object>).has('endAtMillis') &&
      (value as Map<string, Object>).has('courseName') && (value as Map<string, Object>).has('location');
    const active = await this.active();
    if (active === null) {
      this.state = null;
      this.clearEndTimer();
      // The shared Dart coordinator sends full snapshots. Recover through the same native start path.
      if (this.foreground && fullCourse) {
        await this.start(value);
        return;
      }
      throw new LiveActivityChannelError('NO_ACTIVE_ACTIVITY', 'No current course Live View');
    }
    // The Dart coordinator sends full course data after restart; incremental updates need cached data.
    if (this.state === null && !fullCourse) {
      throw new LiveActivityChannelError('NO_ACTIVE_ACTIVITY', 'Restart the activity with full course data');
    }
    const state = new CourseLiveState(value, this.state);
    const view = await this.buildView(state, (active.sequence ?? 0) + 1);
    checkLiveViewResult(await liveViewManager.updateLiveView(view));
    if (!this.disposed) {
      this.state = state;
      this.scheduleEnd(state.endAt);
    }
  }

  private async end(): Promise<void> {
    const active = await this.active();
    if (active !== null) {
      active.sequence = (active.sequence ?? 0) + 1;
      active.isMute = true;
      active.liveViewData.primary.keepTime = 0;
      try {
        checkLiveViewResult(await liveViewManager.stopLiveView(active));
      } catch (error) {
        if ((error as BusinessError).code !== 1003500009 && (error as BusinessError).code !== 1003500010) throw error as Error;
      }
    }
    this.state = null;
    this.clearEndTimer();
  }

  private async requireEnabled(): Promise<void> {
    if (!await this.isEnabled()) {
      throw new LiveActivityChannelError('NOT_AUTHORIZED', 'Enable Live View in the app system settings');
    }
  }

  private async buildView(state: CourseLiveState, sequence: number): Promise<liveViewManager.LiveView> {
    const clickAction = await wantAgent.getWantAgent({
      wants: [{ bundleName: this.context.applicationInfo.name, abilityName: 'EntryAbility' }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: COURSE_LIVE_VIEW_ID,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    });
    const duration = Math.max(0, state.endAt - Date.now());
    const content: liveViewManager.RichText[] = [];
    if (state.location.length > 0) content.push({ text: `${state.location} · `.slice(0, 127) });
    content.push({ text: `${this.remainingLabel} ${TIMER_PLACEHOLDER}` });
    if (state.nextCourseName.length > 0) {
      const nextCourse = state.nextLocation.length > 0 ?
        `${state.nextCourseName} · ${state.nextLocation}` : state.nextCourseName;
      content.push({ text: ` · ${this.nextLabel}: ${nextCourse}`.slice(0, 127) });
    }
    const primary: liveViewManager.PrimaryData = {
      title: state.courseName,
      content: content,
      keepTime: 0,
      clickAction: clickAction,
      layoutData: { layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_DEFAULT }
    };
    return {
      id: COURSE_LIVE_VIEW_ID,
      // Course countdown uses the TIMER scenario; Huawei must approve this scenario for the app.
      event: 'TIMER',
      sequence: sequence,
      isMute: true,
      timer: {
        time: duration, isCountdown: true, isPaused: false,
        capsuleCountdownPreset: { presetTitle: this.endedLabel, presetContent: this.endedLabel }
      },
      liveViewData: {
        primary: primary,
        capsule: {
          type: liveViewManager.CapsuleType.CAPSULE_TYPE_TIMER,
          status: 1, time: duration, isCountdown: true, isPaused: false,
          icon: 'course_live_icon.svg',
          backgroundColor: '#FF991F20',
          content: state.courseName.slice(0, 127)
        }
      }
    };
  }

  private scheduleEnd(endAt: number): void {
    this.clearEndTimer();
    this.endTimer = setTimeout(() => {
      this.queue = this.queue.then(async () => {
        if (this.disposed || this.state?.endAt !== endAt) return;
        try { await this.end(); } catch (error) {
          hilog.warn(0x0000, 'CourseLiveView', 'Could not end course Live View: %{public}s',
            `${(error as BusinessError).code ?? 'unknown'}`);
        }
      });
    }, Math.max(0, endAt - Date.now()));
  }

  private clearEndTimer(): void {
    if (this.endTimer !== -1) clearTimeout(this.endTimer);
    this.endTimer = -1;
  }

  dispose(): void {
    this.disposed = true;
    this.clearEndTimer();
    this.state = null;
    // Countdown rendering belongs to the system. A later engine can recover/end the same owned ID.
  }
}
