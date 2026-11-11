import deviceInfo from '@ohos.deviceInfo';
import { NativeAppearance } from './NativeUiModels';
import lazy { NativeUiMaterialApi26 } from './NativeUiMaterialApi26';

// Guard immersive switches (API 26) for the API 20 minimum.
export class NativeUiMaterial {
  static hasApi26(): boolean {
    return deviceInfo.sdkApiVersion >= 26;
  }
}

export class NativeSwitchAppearance implements AttributeModifier<ToggleAttribute> {
  private appearance: NativeAppearance;

  constructor(appearance: NativeAppearance) {
    this.appearance = appearance;
  }

  applyNormalAttribute(instance: ToggleAttribute): void {
    instance.selectedColor(this.appearance.accent());
    if (NativeUiMaterial.hasApi26()) {
      NativeUiMaterialApi26.applySwitch(instance, this.appearance);
    }
  }
}
