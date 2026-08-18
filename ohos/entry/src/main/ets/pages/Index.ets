import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos'
import { uiMaterial, window } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ImmersiveLaunchOverlay } from '../components/ImmersiveLaunchOverlay'
import { NativeImmersiveDock } from '../components/NativeImmersiveDock'

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";
  // 沉浸光感启动遮罩：覆盖在 FlutterPage 之上，Flutter 首帧就绪后淡出移除
  @State showImmersiveOverlay: boolean = true;
  // 状态栏高度（vp），用于顶部沉浸光感条
  @State statusBarHeight: number = 40;
  private readonly immersiveSupported: boolean = deviceInfo.sdkApiVersion >= 23;

  aboutToAppear(): void {
    // 读取状态栏避让区高度，让顶部光感条精确贴合状态栏
    window.getLastWindow(this.context).then((win: window.Window) => {
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      if (area.topRect.height > 0) {
        this.statusBarHeight = px2vp(area.topRect.height);
      }
    }).catch(() => {
      // 保持默认值
    });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        FlutterPage({ viewId: this.viewId })
      }
      .width('100%')
      .height('100%')

      // 原生沉浸光感悬浮底栏（配置由 Dart 侧经 MethodChannel 推送；
      // 未启用或被二级页面覆盖时组件内部不渲染，小白条区域保持沉浸）
      NativeImmersiveDock()

      // 顶部状态栏沉浸光感条：贴合状态栏的一条超薄光感材质
      if (this.immersiveSupported) {
        Column() {}
        .width('100%')
        .height(this.statusBarHeight)
        .systemMaterial(new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
          colorInvert: true,
          applyShadow: false,
          interactive: false
        }))
        .position({ x: 0, y: 0 })
      }

      if (this.showImmersiveOverlay) {
        ImmersiveLaunchOverlay({
          onDismiss: () => {
            this.showImmersiveOverlay = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
