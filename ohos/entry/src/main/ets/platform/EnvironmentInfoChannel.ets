import deviceInfo from '@ohos.deviceInfo';
import { MethodCall, MethodResult } from '@ohos/flutter_ohos';

// Public device constants, available since API 6. No device-identifier permission.
export class EnvironmentInfoChannel {
  handle(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'getDeviceInfo') {
      result.notImplemented();
      return;
    }

    try {
      const info = new Map<string, string>();
      info.set('brand', deviceInfo.brand);
      info.set('manufacturer', deviceInfo.manufacture);
      info.set('marketName', deviceInfo.marketName);
      info.set('model', deviceInfo.productModel);
      info.set('deviceType', deviceInfo.deviceType);
      info.set('osFullName', deviceInfo.osFullName);
      info.set('displayVersion', deviceInfo.displayVersion);
      info.set('osReleaseType', deviceInfo.osReleaseType);
      info.set('sdkApiVersion', deviceInfo.sdkApiVersion.toString());
      info.set('firstApiVersion', deviceInfo.firstApiVersion.toString());
      info.set('supportedAbis', deviceInfo.abiList);
      info.set('securityPatchTag', deviceInfo.securityPatchTag);
      info.set('buildType', deviceInfo.buildType);
      result.success(info);
    } catch (error) {
      result.error('DEVICE_INFO_FAILED', (error as Error).message, null);
    }
  }
}
