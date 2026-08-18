import {
  FlutterEngine,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';

/** Dart 侧推送过来的底栏配置（字段与 immersive_dock_service.dart 对齐） */
export interface DockTabInfo {
  id: string;
  label: string;
  icon: string;
  badge: boolean;
}

export interface DockConfig {
  enabled: boolean;
  tabs: DockTabInfo[];
  selectedIndex: number;
  /** uiMaterial.ImmersiveStyle 枚举值（0 超薄 ~ 4 超厚） */
  style: number;
  /** 智能反色 */
  colorInvert: boolean;
  /** 按压点光源交互 */
  interactive: boolean;
  /** 首页被二级页面覆盖：true 时胶囊隐藏，改渲染底部沉浸光感条 */
  covered: boolean;
}

export const DOCK_CONFIG_KEY = 'dockConfigJson';
const CHANNEL_NAME = 'bugaoshan/immersive_dock';

/**
 * 原生沉浸光感底栏桥接（单例）。
 *
 * Dart → ArkTS：`updateDock` 写入 AppStorage[DOCK_CONFIG_KEY]，
 *   NativeImmersiveDock 通过 @StorageLink 自动刷新。
 * ArkTS → Dart：点击标签时 `invokeMethod('onDockTap', index)`。
 */
export class DockBridge implements MethodCallHandler {
  private static instance: DockBridge | null = null;
  private channel: MethodChannel | null = null;

  static getInstance(): DockBridge {
    if (DockBridge.instance == null) {
      DockBridge.instance = new DockBridge();
    }
    return DockBridge.instance!;
  }

  /** 在 EntryAbility.configureFlutterEngine 中调用 */
  setup(engine: FlutterEngine): void {
    this.channel = new MethodChannel(engine.dartExecutor.getBinaryMessenger(), CHANNEL_NAME);
    this.channel.setMethodCallHandler(this);
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method == 'updateDock') {
      try {
        // StandardMessageCodec 把 Dart Map 解码为 ES Map（不可直接 JSON.stringify），
        // 逐字段读出后组装成可序列化的普通对象。
        const args = call.args as Map<string, Object>;
        const tabsRaw = args.get('tabs') as Array<Object>;
        const tabs: DockTabInfo[] = [];
        tabsRaw.forEach((t: Object) => {
          const m = t as Map<string, Object>;
          const tab: DockTabInfo = {
            id: m.get('id') as string,
            label: m.get('label') as string,
            icon: m.get('icon') as string,
            badge: m.get('badge') as boolean,
          };
          tabs.push(tab);
        });
        const cfg: DockConfig = {
          enabled: args.get('enabled') as boolean,
          tabs: tabs,
          selectedIndex: args.get('selectedIndex') as number,
          style: args.get('style') as number,
          colorInvert: args.get('colorInvert') as boolean,
          interactive: args.get('interactive') as boolean,
          covered: (args.get('covered') ?? false) as boolean,
        };
        const json = JSON.stringify(cfg);
        // 与当前配置相同则跳过写入：点击标签时原生侧已本地更新过选中态，
        // Dart 回推相同内容若再写一次会触发二次刷新（光标动画被打断重启，
        // 表现为切换卡顿）。
        if (AppStorage.get<string>(DOCK_CONFIG_KEY) != json) {
          AppStorage.setOrCreate(DOCK_CONFIG_KEY, json);
        }
        result.success(null);
      } catch (e) {
        result.error('dock_config_error', String(e), null);
      }
      return;
    }
    result.notImplemented();
  }

  /** 底栏点击事件回传 Dart */
  sendTap(index: number): void {
    this.channel?.invokeMethod('onDockTap', index);
  }
}
