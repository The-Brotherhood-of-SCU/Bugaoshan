import 'package:bugaoshan/utils/share_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('分享锚点来自触发控件的非零全局区域', (tester) async {
    final anchorKey = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(key: anchorKey, width: 120, height: 60)),
      ),
    );

    final origin = sharePositionOriginForContext(anchorKey.currentContext!);

    expect(origin.width, 120);
    expect(origin.height, 60);
    expect(origin.isEmpty, isFalse);
  });

  testWidgets('调用方提供的有效锚点优先', (tester) async {
    final anchorKey = GlobalKey();
    const preferred = Rect.fromLTWH(10, 20, 30, 40);

    await tester.pumpWidget(SizedBox(key: anchorKey, width: 100, height: 100));

    expect(
      sharePositionOriginForContext(
        anchorKey.currentContext!,
        preferred: preferred,
      ),
      preferred,
    );
  });
}
