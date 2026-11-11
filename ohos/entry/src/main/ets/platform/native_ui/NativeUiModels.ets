// StandardMessageCodec decodes Dart maps as Map, not plain ArkTS objects.
export class NativeArguments {
  private values: Map<string, Object>;

  constructor(value: Object) {
    if (!(value instanceof Map)) throw new Error('Expected a configuration map');
    this.values = value as Map<string, Object>;
  }

  text(key: string, fallback: string = ''): string {
    const value = this.values.get(key);
    return typeof value === 'string' ? value : fallback;
  }

  flag(key: string, fallback: boolean = false): boolean {
    const value = this.values.get(key);
    return typeof value === 'boolean' ? value : fallback;
  }

  number(key: string, fallback: number, minimum: number, maximum: number): number {
    const value = this.values.get(key);
    return typeof value === 'number' && Number.isFinite(value) ?
      Math.max(minimum, Math.min(maximum, value)) : fallback;
  }
}

export class NativeAppearance {
  tint: number = 0xff006a60;
  dark: boolean = false;
  reduceMotion: boolean = false;
  highContrast: boolean = false;
  textScale: number = 1;
  rtl: boolean = false;

  constructor(args: NativeArguments) {
    this.tint = args.number('tint', this.tint, 0, 0xffffffff) >>> 0;
    this.dark = args.text('brightness') === 'dark';
    this.reduceMotion = args.flag('reduceMotion');
    this.highContrast = args.flag('highContrast');
    this.textScale = args.number('textScale', 1, 1, 2);
    this.rtl = args.text('direction') === 'rtl';
  }

  foreground(): number {
    return this.dark ? 0xfff1f3f5 : 0xff182431;
  }

  surface(): number {
    return this.dark ? 0xff202124 : 0xfff1f3f5;
  }

  accent(): number {
    return this.highContrast ? this.foreground() : this.tint;
  }
}

export class NativeControlConfiguration extends NativeAppearance {
  kind: string;
  label: string;
  symbol: string;
  value: boolean;
  enabled: boolean;
  loading: boolean;
  prominent: boolean;

  constructor(value: Object) {
    const args = new NativeArguments(value);
    super(args);
    this.kind = args.text('kind');
    if (this.kind !== 'button' && this.kind !== 'switch') throw new Error('Unknown control kind');
    this.label = args.text('label');
    this.symbol = args.text('symbol');
    this.value = args.flag('value');
    this.loading = args.flag('loading');
    this.enabled = args.flag('enabled') && !this.loading;
    this.prominent = args.text('style') === 'prominent';
  }
}
