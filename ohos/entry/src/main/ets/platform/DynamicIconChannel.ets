import bundleManager from '@ohos.bundle.bundleManager';
import deviceInfo from '@ohos.deviceInfo';
import { MethodCall, MethodResult } from '@ohos/flutter_ohos';

// Bundled alternate icons use the API 26 bundleManager route. The app supports API 20+.
export class DynamicIconChannel {
  private switching: boolean = false;

  async handle(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method === 'supportsAlternateIcons') {
      result.success(deviceInfo.sdkApiVersion >= 26);
      return;
    }
    if (deviceInfo.sdkApiVersion < 26) {
      if (call.method === 'getAvailableIcons') {
        result.success([]);
      } else if (call.method === 'getCurrentIconName') {
        result.success(null);
      } else if (call.method === 'setAlternateIconName') {
        result.error('UNSUPPORTED', 'Alternate icons require HarmonyOS API 26', null);
      } else {
        result.notImplemented();
      }
      return;
    }
    try {
      if (call.method === 'getAvailableIcons') {
        const icons = await bundleManager.getAlternateIcons();
        result.success(icons.map((icon) => icon.iconName));
      } else if (call.method === 'getCurrentIconName') {
        const icons = await bundleManager.getAlternateIcons();
        const selected = icons.find((icon) => icon.enabled);
        result.success(selected ? selected.iconName : null);
      } else if (call.method === 'setAlternateIconName') {
        if (this.switching) {
          result.error('BUSY', 'An icon change is already in progress', null);
          return;
        }
        const name = call.argument('iconName') as string | null;
        if (name !== null && name !== undefined && name !== '' && name !== 'old') {
          result.error('INVALID_ARGUMENT', 'Unknown alternate icon', null);
          return;
        }
        this.switching = true;
        try {
          await bundleManager.setAlternateIcon(name ?? '');
          result.success(null);
        } finally {
          this.switching = false;
        }
      } else {
        result.notImplemented();
      }
    } catch (error) {
      result.error('ICON_FAILED', (error as Error).message, null);
    }
  }
}
