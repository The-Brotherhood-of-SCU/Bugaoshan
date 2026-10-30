import { BinaryMessenger } from '@ohos/flutter_ohos';
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import { NativeControlConfiguration } from './NativeUiModels';
import { NativeSwitchAppearance } from './NativeUiMaterial';
import { nativeControlIcon } from './NativeUiIcons';
import { NativeUiView } from './NativeUiView';

@Observed
export class NativeControlState {
  configuration: NativeControlConfiguration;
  value: boolean;

  constructor(configuration: NativeControlConfiguration) {
    this.configuration = configuration;
    this.value = configuration.value;
  }
}

export class NativeControlView extends NativeUiView {
  state: NativeControlState;
  private pendingValue: boolean | null = null;

  constructor(messenger: BinaryMessenger, viewId: number, configuration: NativeControlConfiguration,
    onDispose: (view: NativeUiView) => void) {
    super(messenger, 'bugaoshan/liquid_glass_control', viewId, onDispose);
    this.state = new NativeControlState(configuration);
  }

  protected update(value: Object): void {
    const next = new NativeControlConfiguration(value);
    if (next.kind !== this.state.configuration.kind) throw new Error('Control kind cannot change');
    this.pendingValue = null;
    this.state.configuration = next;
    // Track native edits separately so Flutter can restore a rejected value.
    this.state.value = next.value;
  }

  activate(): void {
    const config = this.state.configuration;
    if (!this.disposed && config.kind === 'button' && config.enabled) this.emit('activate', null);
  }

  change(value: boolean): void {
    const config = this.state.configuration;
    if (this.disposed || config.kind !== 'switch' || !config.enabled ||
      value === config.value || value === this.pendingValue) return;
    this.pendingValue = value;
    this.state.value = value;
    this.emit('change', value);
  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(NativeControlBuilder);
  }
}

@Builder
function NativeControlBuilder(params: Params) {
  NativeControlComponent({
    state: (params.platformView as NativeControlView).state,
    view: params.platformView as NativeControlView
  })
}

@Component
struct NativeControlComponent {
  @ObjectLink state: NativeControlState;
  @Require view: NativeControlView;

  private foreground(): number {
    const config = this.state.configuration;
    return config.prominent ? (config.highContrast && config.dark ? 0xff182431 : 0xffffffff) :
      config.accent();
  }

  build() {
    WithTheme({ colorMode: this.state.configuration.dark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT }) {
      Row() {
        if (this.state.configuration.kind === 'switch') {
          Toggle({ type: ToggleType.Switch, isOn: $$this.state.value })
            .width(52).height(32).margin(0)
            .enabled(this.state.configuration.enabled)
            .attributeModifier(new NativeSwitchAppearance(this.state.configuration))
            .accessibilityText(this.state.configuration.label)
            .onChange((value: boolean) => this.view.change(value))
        } else {
          // Body buttons deliberately use native Button styling. API 26 material
          // on Button is limited to native navigation/title/tab-bar contexts.
          Button({ type: ButtonType.Capsule, stateEffect: !this.state.configuration.reduceMotion }) {
            Row({ space: 8 }) {
              if (this.state.configuration.loading) {
                LoadingProgress().width(20).height(20).color(this.foreground())
                  .accessibilityLevel('no')
              } else if (this.state.configuration.symbol !== '') {
                SymbolGlyph(nativeControlIcon(this.state.configuration.symbol))
                  .fontSize(20).fontColor([this.foreground()])
                  .accessibilityLevel('no')
              }
              Text(this.state.configuration.label)
                .fontSize(`${16 * this.state.configuration.textScale}vp`)
                .fontWeight(FontWeight.Medium).fontColor(this.foreground())
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .accessibilityLevel('no')
            }.justifyContent(FlexAlign.Center).width('100%')
          }
          .width('100%').height('100%').padding({ left: 12, right: 12 })
          .backgroundColor(this.state.configuration.prominent ? this.state.configuration.accent() :
            this.state.configuration.surface())
          .enabled(this.state.configuration.enabled)
          .accessibilityText(this.state.configuration.label)
          .onClick(() => this.view.activate())
        }
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Center)
      .direction(this.state.configuration.rtl ? Direction.Rtl : Direction.Ltr)
      .accessibilityLevel('no')
      .onClick(() => {
        // Include the surrounding touch target. pendingValue suppresses the
        // bubbled click when Toggle already emitted the same value.
        if (this.state.configuration.kind === 'switch') {
          this.view.change(!this.state.configuration.value);
        }
      })
    }
  }
}
