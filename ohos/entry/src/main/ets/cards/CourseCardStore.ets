import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import i18n from '@ohos.i18n';
import hilog from '@ohos.hilog';
import formBindingData from '@ohos.app.form.formBindingData';
import formProvider from '@ohos.app.form.formProvider';
import { CardBinding, CourseSnapshot, makeCardView, nextRefreshMinutes } from './CourseCardModel';
import { loadCourseSnapshot } from './CourseCardDatabase';

export class CourseCardStore {
  private context: common.Context;
  private directory: string;
  private settingsPath: string;

  constructor(context: common.Context) {
    this.context = context;
    this.directory = `${context.filesDir}/course_cards`;
    this.settingsPath = `${this.directory}/show-tomorrow`;
    if (!fs.accessSync(this.directory)) {
      try {
        fs.mkdirSync(this.directory, true);
      } catch (error) {
        // The UIAbility and extension may create their shared directory together.
        if (!fs.accessSync(this.directory) || !fs.statSync(this.directory).isDirectory()) {
          throw new Error((error as Error).message);
        }
      }
    }
  }

  setShowTomorrow(value: boolean): void {
    const temporary = `${this.settingsPath}.${util.generateRandomUUID()}.tmp`;
    try {
      const file = fs.openSync(temporary, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        if (fs.writeSync(file.fd, new util.TextEncoder().encodeInto(value ? '1' : '0').buffer) !== 1) {
          throw new Error('Could not save course card setting');
        }
        fs.fsyncSync(file.fd);
      } finally {
        fs.closeSync(file);
      }
      fs.renameSync(temporary, this.settingsPath);
    } finally {
      if (fs.accessSync(temporary)) fs.unlinkSync(temporary);
    }
  }

  async load(): Promise<CourseSnapshot> {
    try {
      const showTomorrow = fs.accessSync(this.settingsPath) && fs.readTextSync(this.settingsPath) === '1';
      return await loadCourseSnapshot(this.context, showTomorrow);
    } catch (error) {
      hilog.warn(0x0000, 'CourseCard', 'Cannot read course database: %{public}s', (error as Error).message);
      return new CourseSnapshot();
    }
  }

  bindingData(snapshot: CourseSnapshot = new CourseSnapshot()): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(
      new CardBinding(makeCardView(snapshot, i18n.System.getSystemLanguage())));
  }

  private validId(id: string): boolean {
    return typeof id === 'string' && /^\d{1,20}$/.test(id) && id !== '0';
  }

  remember(id: string): void {
    if (!this.validId(id)) return;
    // One file per instance: the UI and FormExtension processes never rewrite a shared index.
    const file = fs.openSync(`${this.directory}/${id}.form`, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
    fs.closeSync(file);
  }

  forget(id: string): void {
    if (!this.validId(id)) return;
    const path = `${this.directory}/${id}.form`;
    if (fs.accessSync(path)) fs.unlinkSync(path);
  }

  async refresh(id: string, snapshot?: CourseSnapshot): Promise<void> {
    if (!this.validId(id) || !fs.accessSync(`${this.directory}/${id}.form`)) return;
    const data = snapshot ?? await this.load();
    await formProvider.updateForm(id, this.bindingData(data));
    await this.scheduleNext(id, data);
  }

  async scheduleNext(id: string, snapshot: CourseSnapshot): Promise<void> {
    if (!this.validId(id) || !fs.accessSync(`${this.directory}/${id}.form`)) return;
    try {
      const delay = nextRefreshMinutes(snapshot);
      // Regular 30-minute updates already cover the other cases.
      if (delay < 30) await formProvider.setFormNextRefreshTime(id, delay);
    } catch (error) {
      hilog.warn(0x0000, 'CourseCard', 'Refresh scheduling unavailable: %{public}s', (error as Error).message);
    }
  }

  async refreshAll(): Promise<void> {
    const entries = fs.listFileSync(this.directory).filter((entry: string) => /^\d{1,20}\.form$/.test(entry));
    if (entries.length === 0) return;
    const snapshot = await this.load();
    for (const entry of entries) {
      try {
        await this.refresh(entry.substring(0, entry.length - 5), snapshot);
      } catch (error) {
        // A removed/unavailable instance cannot prevent the other instances updating.
        hilog.warn(0x0000, 'CourseCard', 'Instance update failed: %{public}s', (error as Error).message);
      }
    }
  }
}
