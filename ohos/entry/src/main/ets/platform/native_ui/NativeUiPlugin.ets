import common from '@ohos.app.ability.common';
import {
  BinaryMessenger, FlutterPlugin, FlutterPluginBinding, MethodCall, MethodChannel,
  MethodResult, PlatformView, PlatformViewFactory, StandardMessageCodec
} from '@ohos/flutter_ohos';
import { NativeControlConfiguration } from './NativeUiModels';
import { NativeControlView } from './NativeControlView';
import { NativeUiView } from './NativeUiView';

class NativeUiFactory extends PlatformViewFactory {
  private messenger: BinaryMessenger;
  private views: Set<NativeUiView>;

  constructor(messenger: BinaryMessenger, views: Set<NativeUiView>) {
    super(StandardMessageCodec.INSTANCE);
    this.messenger = messenger;
    this.views = views;
  }

  create(_context: common.Context, viewId: number, args: Object): PlatformView {
    const remove = (view: NativeUiView): void => { this.views.delete(view); };
    const view = new NativeControlView(this.messenger, viewId, new NativeControlConfiguration(args), remove);
    this.views.add(view);
    return view;
  }
}

export class NativeUiPlugin implements FlutterPlugin {
  static readonly NAME: string = 'BugaoshanNativeUiPlugin';
  private channel: MethodChannel | null = null;
  private views: Set<NativeUiView> = new Set();

  getUniqueClassName(): string { return NativeUiPlugin.NAME; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    const messenger = binding.getBinaryMessenger();
    const registry = binding.getPlatformViewRegistry();
    const controls = registry.registerViewFactory('bugaoshan/liquid_glass_control',
      new NativeUiFactory(messenger, this.views));
    this.channel = new MethodChannel(messenger, 'bugaoshan/liquid_glass');
    this.channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method === 'isSupported') {
          result.success(controls);
        } else if (call.method === 'getCapabilities') {
          const capabilities = new Map<string, Object>();
          capabilities.set('version', 1);
          capabilities.set('backend', 'ohos');
          capabilities.set('button', controls);
          capabilities.set('switch', controls);
          result.success(capabilities);
        } else {
          result.notImplemented();
        }
      }
    });
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    for (const view of this.views) view.dispose();
    this.views.clear();
  }
}
