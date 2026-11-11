import { BinaryMessenger, MethodCall, MethodChannel, MethodResult, PlatformView } from '@ohos/flutter_ohos';

/// One handler per view; neither configuration nor callbacks use AppStorage.
export abstract class NativeUiView extends PlatformView {
  protected disposed: boolean = false;
  private channel: MethodChannel;
  private onDispose: (view: NativeUiView) => void;

  constructor(messenger: BinaryMessenger, viewType: string, viewId: number,
    onDispose: (view: NativeUiView) => void) {
    super();
    this.onDispose = onDispose;
    this.channel = new MethodChannel(messenger, `${viewType}/${viewId}`);
    this.channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (this.disposed) {
          result.error('DISPOSED', 'Native view has been disposed', null);
        } else if (call.method !== 'update') {
          result.notImplemented();
        } else {
          try {
            this.update(call.args as Object);
            result.success(null);
          } catch (error) {
            result.error('INVALID_ARGUMENT', (error as Error).message, null);
          }
        }
      }
    });
  }

  protected abstract update(value: Object): void;

  protected emit(method: string, value: string | boolean | null): void {
    if (!this.disposed) this.channel.invokeMethod(method, value);
  }

  protected releaseView(): void {}

  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    this.channel.setMethodCallHandler(null);
    this.releaseView();
    this.onDispose(this);
  }
}
