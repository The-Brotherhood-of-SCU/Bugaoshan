import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

/**
 * 沉浸光感启动遮罩（Immersive Material Launch Overlay）
 *
 * 不高山上的全部业务 UI 由 Flutter 引擎渲染，ArkUI 侧无法对 Flutter
 * 绘制内容直接施加系统材质，因此沉浸光感（ImmersiveMaterial）接入在
 * 启动遮罩层：App 冷启动时先呈现通透玻璃质感的启动画面，Flutter
 * 首帧渲染完成后遮罩淡出并移除。
 *
 * 兼容性：沉浸光感需要 HarmonyOS 6.1.0（API 23）及以上；
 * 低版本设备自动降级为普通毛玻璃（backgroundBlurStyle）方案。
 */
@Component
export struct ImmersiveLaunchOverlay {
  // 遮罩消失回调：淡出动画结束后从组件树移除本遮罩
  onDismiss: () => void = () => {};
  @State private overlayOpacity: number = 1;
  // 运行设备是否支持沉浸光感（API 23+）
  private readonly immersiveSupported: boolean = deviceInfo.sdkApiVersion >= 23;

  aboutToAppear(): void {
    // 预留 Flutter 引擎预热与首帧渲染时间
    setTimeout(() => {
      animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
        this.overlayOpacity = 0;
      });
      setTimeout(() => {
        this.onDismiss();
      }, 350);
    }, 1200);
  }

  @Builder
  CardContent() {
    Image($r('app.media.icon'))
      .width(88)
      .height(88)
      .borderRadius(22)

    Text($r('app.string.EntryAbility_label'))
      .fontSize(24)
      .fontWeight(FontWeight.Bold)
      .fontColor(Color.White)

    Text('沉浸光感 · Immersive Material')
      .fontSize(12)
      .fontColor('#CCFFFFFF')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 深色渐变底，衬托光感材质
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [['#1B2A6B', 0.0], ['#3B2E7E', 0.5], ['#123B63', 1.0]]
        })

      // 顶部光斑
      Circle()
        .width(280)
        .height(280)
        .fill('#3D8BFD')
        .opacity(0.35)
        .blur(80)
        .offset({ x: -70, y: -160 })

      // 底部光斑
      Circle()
        .width(240)
        .height(240)
        .fill('#8A5CF6')
        .opacity(0.30)
        .blur(70)
        .offset({ x: 90, y: 200 })

      if (this.immersiveSupported) {
        // API 23+：沉浸光感材质（毛玻璃 + 流光 + 按压点光源 + 智能反色）
        Column({ space: 18 }) {
          this.CardContent()
        }
        .padding({ top: 44, bottom: 44, left: 52, right: 52 })
        .borderRadius(32)
        .systemMaterial(new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.REGULAR,
          colorInvert: true,
          applyShadow: true,
          interactive: true
        }))
      } else {
        // 低版本降级：普通毛玻璃
        Column({ space: 18 }) {
          this.CardContent()
        }
        .padding({ top: 44, bottom: 44, left: 52, right: 52 })
        .borderRadius(32)
        .backgroundColor('#26FFFFFF')
        .backgroundBlurStyle(BlurStyle.Thick)
      }
    }
    .width('100%')
    .height('100%')
    .opacity(this.overlayOpacity)
  }
}
