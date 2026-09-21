import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LOCAL_ORIGIN } from './BridgeProtocol';

interface ViewportPadding {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

interface ViewportMetrics {
  padding: ViewportPadding;
  keyboardVisible: boolean;
}

// 以物理像素传输安全区，由 Flutter 按当前 devicePixelRatio 换算。
export class NativeViewport {
  private readonly controller: webview.WebviewController;
  private hostWindow?: window.Window;
  private ready: Promise<void> = Promise.resolve();
  private generation: number = 0;
  private pageReady: boolean = false;
  private lastPublished?: string;

  private readonly onAvoidAreaChange = (_event: window.AvoidAreaOptions): void => {
    this.publish();
  };
  private readonly onWindowSizeChange = (_size: window.Size): void => {
    this.publish();
  };

  constructor(controller: webview.WebviewController) {
    this.controller = controller;
  }

  attach(context: common.Context): void {
    const generation = ++this.generation;
    this.ready = window.getLastWindow(context).then((hostWindow: window.Window) => {
      if (generation !== this.generation) {
        return;
      }
      this.hostWindow = hostWindow;
      hostWindow.on('avoidAreaChange', this.onAvoidAreaChange);
      hostWindow.on('windowSizeChange', this.onWindowSizeChange);
      this.publish();
    }).catch(() => {
      hilog.warn(0x0000, 'NativeViewport', '监听窗口安全区失败');
    });
  }

  private readAvoidArea(type: window.AvoidAreaType): window.AvoidArea | undefined {
    try {
      return this.hostWindow?.getWindowAvoidArea(type);
    } catch {
      // 部分窗口形态不提供挖孔区或手势条区域，其他类型仍可使用。
      return undefined;
    }
  }

  private readMetrics(): ViewportMetrics | null {
    const hostWindow = this.hostWindow;
    if (hostWindow === undefined) {
      return null;
    }
    try {
      const bounds = hostWindow.getWindowProperties().windowRect;
      const padding: ViewportPadding = { top: 0, right: 0, bottom: 0, left: 0 };
      const types: window.AvoidAreaType[] = [window.AvoidAreaType.TYPE_SYSTEM,
        window.AvoidAreaType.TYPE_CUTOUT, window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR];
      for (const type of types) {
        const area = this.readAvoidArea(type);
        if (area === undefined) {
          continue;
        }
        // Rect 的坐标相对窗口；取各边的遮挡深度，重叠的状态栏和挖孔不累加。
        if (area.topRect.height > 0 && area.topRect.width > 0) {
          padding.top = Math.max(padding.top, area.topRect.top + area.topRect.height);
        }
        if (area.bottomRect.height > 0 && area.bottomRect.width > 0) {
          padding.bottom = Math.max(padding.bottom, bounds.height - area.bottomRect.top);
        }
        if (area.leftRect.width > 0 && area.leftRect.height > 0) {
          padding.left = Math.max(padding.left, area.leftRect.left + area.leftRect.width);
        }
        if (area.rightRect.width > 0 && area.rightRect.height > 0) {
          padding.right = Math.max(padding.right, bounds.width - area.rightRect.left);
        }
      }
      const keyboard = this.readAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD);
      return { padding: padding, keyboardVisible: keyboard !== undefined && keyboard.bottomRect.height > 0 };
    } catch {
      hilog.warn(0x0000, 'NativeViewport', '读取窗口安全区失败');
      return null;
    }
  }

  async getMetrics(): Promise<Object | null> {
    await this.ready;
    return this.readMetrics();
  }

  async setDarkMode(dark: boolean): Promise<void> {
    await this.ready;
    const hostWindow = this.hostWindow;
    if (hostWindow === undefined) {
      return;
    }
    const contentColor = dark ? '#FFFFFFFF' : '#FF000000';
    await hostWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: contentColor,
      navigationBarContentColor: contentColor
    });
  }

  onPageBegin(): void {
    this.pageReady = false;
    this.lastPublished = undefined;
  }

  onPageEnd(): void {
    this.pageReady = true;
    this.publish();
  }

  private publish(): void {
    if (!this.pageReady) {
      return;
    }
    const metrics = this.readMetrics();
    if (metrics === null) {
      return;
    }
    const serialized = JSON.stringify(metrics);
    if (serialized === this.lastPublished) {
      return;
    }
    this.lastPublished = serialized;
    const script = 'if (location.origin === ' + JSON.stringify(LOCAL_ORIGIN) + ') {' +
      'window.bugaoshanViewportChanged?.(' + JSON.stringify(serialized) + '); }';
    this.controller.runJavaScript(script).catch(() => {
      this.lastPublished = undefined;
      if (this.pageReady) {
        hilog.warn(0x0000, 'NativeViewport', '向网页同步安全区失败');
      }
    });
  }

  dispose(): void {
    this.generation++;
    this.pageReady = false;
    this.lastPublished = undefined;
    const hostWindow = this.hostWindow;
    this.hostWindow = undefined;
    if (hostWindow !== undefined) {
      try {
        hostWindow.off('avoidAreaChange', this.onAvoidAreaChange);
      } catch {
        hilog.warn(0x0000, 'NativeViewport', '取消安全区监听失败');
      }
      try {
        hostWindow.off('windowSizeChange', this.onWindowSizeChange);
      } catch {
        hilog.warn(0x0000, 'NativeViewport', '取消窗口尺寸监听失败');
      }
    }
  }
}
