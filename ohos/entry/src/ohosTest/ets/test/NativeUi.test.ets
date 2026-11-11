import { describe, it, expect } from '@ohos/hypium';
import { NativeControlConfiguration } from '../../../main/ets/platform/native_ui/NativeUiModels';

export default function nativeUiTest() {
  describe('NativeUiConfiguration', () => {
    it('loading disables activation and transmitted text scaling is bounded', 0, () => {
      const args = new Map<string, Object>();
      args.set('kind', 'button');
      args.set('enabled', true);
      args.set('loading', true);
      args.set('textScale', 10);
      const config = new NativeControlConfiguration(args);
      expect(config.enabled).assertFalse();
      expect(config.textScale).assertEqual(2);
    });
  });
}
