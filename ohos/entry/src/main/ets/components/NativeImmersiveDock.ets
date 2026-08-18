import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { DockBridge, DOCK_CONFIG_KEY, DockConfig, DockTabInfo } from '../dock/DockBridge';

/** ForEach 条目（ArkTS 禁止无类型对象字面量） */
class TabEntry {
  tab: DockTabInfo;
  index: number;

  constructor(tab: DockTabInfo, index: number) {
    this.tab = tab;
    this.index = index;
  }
}

/** 图标映射：Flutter 侧传入 dock id，这里映射为系统 Symbol 图标 */
class DockIcon {
  static of(id: string): Resource {
    switch (id) {
      case 'course':
        return $r('sys.symbol.book');
      case 'campus':
        return $r('sys.symbol.graduationcap');
      case 'profile':
        return $r('sys.symbol.person');
      case 'grades':
        return $r('sys.symbol.histogram');
      case 'classroom':
        return $r('sys.symbol.house');
      case 'ccyl':
        return $r('sys.symbol.flag');
      case 'notice':
        return $r('sys.symbol.bell');
      case 'ccyl_search':
        return $r('sys.symbol.magnifyingglass');
      case 'ccyl_my':
        return $r('sys.symbol.person');
      case 'ccyl_ordered':
        return $r('sys.symbol.bookmark');
      case 'ccyl_credits':
        return $r('sys.symbol.doc_text');
      default:
        return $r('sys.symbol.star');
    }
  }
}

function parseConfig(json: string): DockConfig | null {
  if (json.length == 0) {
    return null;
  }
  try {
    return JSON.parse(json) as DockConfig;
  } catch (e) {
    return null;
  }
}

/** 点击标签：本地立即更新选中态（光标即时滑动），再回传 Dart 切页 */
function handleTabTap(configJson: string, index: number): void {
  const cfg = parseConfig(configJson);
  if (cfg != null && cfg.selectedIndex != index) {
    cfg.selectedIndex = index;
    AppStorage.setOrCreate(DOCK_CONFIG_KEY, JSON.stringify(cfg));
  }
  DockBridge.getInstance().sendTap(index);
}

/**
 * 单个底栏标签。
 *
 * 独立 @Component + 自有 @StorageLink：选中态变化只重建标签本身，
 * 彻底规避 @Builder 标量参数不刷新 / ForEach 复用导致的光标不跟随问题。
 */
@Component
struct DockTabItem {
  @StorageLink(DOCK_CONFIG_KEY) configJson: string = '';
  @Prop index: number = 0;

  private tabInfo(): DockTabInfo | null {
    const cfg = parseConfig(this.configJson);
    if (cfg == null || this.index >= cfg.tabs.length) {
      return null;
    }
    return cfg.tabs[this.index];
  }

  private isSelected(): boolean {
    const cfg = parseConfig(this.configJson);
    return cfg != null && cfg.selectedIndex == this.index;
  }

  build() {
    Column({ space: 2 }) {
      Stack() {
        SymbolGlyph(DockIcon.of(this.tabInfo()?.id ?? 'star'))
          .fontSize(22)
          .fontColor([this.isSelected() ? $r('sys.color.ohos_id_color_emphasize') :
            $r('sys.color.ohos_id_color_text_secondary')])
        if (this.tabInfo()?.badge ?? false) {
          Circle()
            .width(8)
            .height(8)
            .fill($r('sys.color.ohos_id_color_warning'))
            .offset({ x: 12, y: -6 })
        }
      }

      Text(this.tabInfo()?.label ?? '')
        .fontSize(10)
        .fontWeight(this.isSelected() ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.isSelected() ? $r('sys.color.ohos_id_color_emphasize') :
          $r('sys.color.ohos_id_color_text_secondary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      handleTabTap(this.configJson, this.index);
    })
  }
}

/**
 * ArkUI 原生沉浸光感悬浮底栏（AppGallery 风格）。
 *
 * 系统级 uiMaterial.ImmersiveMaterial 材质悬浮于 FlutterPage 之上，
 * 页面内容可延伸到底栏下方透出光影；选中项带滑动高亮光标（胶囊），
 * 切换时以动画平滑移动。配置由 Dart 侧经 MethodChannel 推送
 * （见 dock/DockBridge.ets），二级页面时 Dart 会推送 enabled=false 隐藏。
 *
 * API < 23 的设备降级为普通毛玻璃样式。
 */
@Component
export struct NativeImmersiveDock {
  @StorageLink(DOCK_CONFIG_KEY) configJson: string = '';
  @State private barWidth: number = 0;
  private readonly immersiveSupported: boolean = deviceInfo.sdkApiVersion >= 23;

  private getStyle(style: number): uiMaterial.ImmersiveStyle {
    switch (style) {
      case 0:
        return uiMaterial.ImmersiveStyle.ULTRA_THIN;
      case 1:
        return uiMaterial.ImmersiveStyle.THIN;
      case 3:
        return uiMaterial.ImmersiveStyle.THICK;
      case 4:
        return uiMaterial.ImmersiveStyle.ULTRA_THICK;
      default:
        return uiMaterial.ImmersiveStyle.REGULAR;
    }
  }

  /** 单个标签宽度（胶囊光标定位用） */
  private itemWidth(cfg: DockConfig): number {
    if (cfg.tabs.length == 0 || this.barWidth <= 0) {
      return 0;
    }
    return this.barWidth / cfg.tabs.length;
  }

  /**
   * 底栏内容（滑动光标 + 标签行）。直接读 @StorageLink 状态，
   * 不传参数，规避 @Builder 参数不刷新问题。
   */
  @Builder
  BarBody() {
    Stack() {
      // 滑动选中光标（胶囊高亮）：位置随 selectedIndex 动画过渡
      Row()
        .width(this.itemWidth(parseConfig(this.configJson)!) - 16)
        .height(46)
        .borderRadius(23)
        .backgroundColor('#1F0A59F7')
        .position({
          x: this.itemWidth(parseConfig(this.configJson)!) *
            parseConfig(this.configJson)!.selectedIndex + 8,
          y: 9
        })
        .animation({ duration: 260, curve: Curve.EaseInOut })

      // 标签行：每项独立 @Component，选中态各自响应
      Row() {
        ForEach(parseConfig(this.configJson)!.tabs.map((tab: DockTabInfo, index: number) => {
          return new TabEntry(tab, index);
        }), (item: TabEntry) => {
          DockTabItem({ index: item.index })
        }, (item: TabEntry) => {
          return item.index.toString() + '_' + item.tab.id;
        })
      }
      .width('100%')
      .height('100%')
    }
    .width('92%')
    .height(64)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.barWidth = newValue.width as number;
    })
  }

  build() {
    // 无配置、未启用或被二级页面覆盖（covered）时不渲染：
    // 二级页面的小白条区域保持内容直达底部的沉浸效果，不加任何遮挡条
    if (this.configJson.length > 0 && (parseConfig(this.configJson)?.enabled ?? false) &&
      (parseConfig(this.configJson)?.covered ?? true) == false &&
      (parseConfig(this.configJson)?.tabs.length ?? 0) > 0) {
      if (this.immersiveSupported) {
        // API 23+：系统级沉浸光感材质。
        // 注意：悬浮间距必须加在材质容器自身（margin 在容器外），
        // 否则材质会把下方空隙包进去，看起来像贴底。
        Column() {
          this.BarBody()
        }
        .borderRadius(32)
        .systemMaterial(new uiMaterial.ImmersiveMaterial({
          style: this.getStyle(parseConfig(this.configJson)!.style),
          colorInvert: parseConfig(this.configJson)!.colorInvert,
          applyShadow: true,
          interactive: parseConfig(this.configJson)!.interactive
        }))
        .margin({ bottom: 28 })
      } else {
        // 低版本降级：普通毛玻璃
        Column() {
          this.BarBody()
        }
        .borderRadius(32)
        .backgroundColor('#59FFFFFF')
        .backgroundBlurStyle(BlurStyle.Thick)
        .margin({ bottom: 28 })
      }
    }
  }
}
