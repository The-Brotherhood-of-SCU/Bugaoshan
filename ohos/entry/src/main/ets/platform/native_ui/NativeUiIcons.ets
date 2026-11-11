// OHOS system symbols; SF Symbol names stay on the shared/iOS side of the bridge.
export function nativeControlIcon(symbol: string): Resource {
  switch (symbol) {
    case 'checkmark': return $r('sys.symbol.checkmark');
    case 'arrow.clockwise': return $r('sys.symbol.arrow_clockwise');
    case 'arrow.counterclockwise': return $r('sys.symbol.arrow_counterclockwise');
    case 'photo': return $r('sys.symbol.picture');
    case 'crop': return $r('sys.symbol.crop');
    case 'trash': return $r('sys.symbol.trash');
    case 'rectangle.portrait.and.arrow.right': return $r('sys.symbol.arrow_right_and_square');
    default: return symbol.startsWith('person') ? $r('sys.symbol.person') :
      $r('sys.symbol.square_grid_2x2');
  }
}
