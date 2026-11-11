import { uiMaterial } from '@kit.ArkUI';
import { NativeAppearance } from './NativeUiModels';

// Load this module only after the API check, including its system-module import.
export class NativeUiMaterialApi26 {
  static isEnabled(): boolean {
    try {
      return uiMaterial.isImmersiveMaterialSupported() &&
        uiMaterial.getMaterialInfo().state !== uiMaterial.MaterialState.DISABLE;
    } catch (_error) {
      return false;
    }
  }

  private static create(appearance: NativeAppearance): uiMaterial.Material {
    if (appearance.highContrast || !NativeUiMaterialApi26.isEnabled()) return uiMaterial.Material.empty;
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: !appearance.reduceMotion,
      lightEffect: appearance.reduceMotion ? null : { color: Color.White }
    });
  }

  static applySwitch(instance: ToggleAttribute, appearance: NativeAppearance): void {
    // Switch uses the system's own immersive thumb parameters.
    instance.systemMaterial(NativeUiMaterialApi26.create(appearance));
  }
}
