import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { window } from '@kit.ArkUI';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { DockBridge } from '../dock/DockBridge';

/**
 * 不高山上 主 Ability。
 *
 * 说明：FlutterAbility 的 onWindowStageCreate 内部已经调用
 * setWindowLayoutFullScreen(true)（沉浸式全屏窗口），页面内容延伸至
 * 状态栏/导航条下方；此处再显式把系统栏颜色固定为全透明，使沉浸行为
 * 不依赖系统默认值。图标对比色沿用系统自动配色（深色主题适配由
 * Flutter 侧系统样式另行处理）。
 * 沉浸光感视效在 pages/Index 中的 ImmersiveLaunchOverlay 启动遮罩层
 * 与 components/NativeImmersiveDock 悬浮底栏实现。
 */
export default class EntryAbility extends FlutterAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    super.onWindowStageCreate(windowStage)
    try {
      windowStage.getMainWindowSync().setWindowSystemBarProperties({
        statusBarColor: '#00FFFFFF',
        navigationBarColor: '#00FFFFFF'
      })
    } catch (e) {
      console.error(`setWindowSystemBarProperties failed: ${e}`)
    }
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    // 原生沉浸光感悬浮底栏桥接（与 Dart 侧 ImmersiveDockService 通信）
    DockBridge.getInstance().setup(flutterEngine)
  }
}
