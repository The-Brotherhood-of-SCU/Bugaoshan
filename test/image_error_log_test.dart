import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/widgets/common/image_error_log.dart';

void main() {
  late AppLogger logger;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    logger = AppLogger();
    getIt.registerSingleton<AppLogger>(logger);
  });
  tearDown(() async {
    await getIt.reset();
    logger.dispose();
  });

  testWidgets('图片失败后父级反复重建只保留首次错误，换图后可再次记录', (tester) async {
    var source = 'first';
    var rebuilds = 0;
    var errorBuilderCalls = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Column(
              children: [
                Text('rebuilds: $rebuilds'),
                ListenableBuilder(
                  listenable: logger,
                  builder: (_, _) => Text('logs: ${logger.entries.length}'),
                ),
                ImageErrorLog(
                  source: source,
                  tag: 'ImageTest',
                  message: 'image failed',
                  builder: (report) => Image(
                    image: _FailingImage(source),
                    errorBuilder: (_, error, stack) {
                      errorBuilderCalls++;
                      report(error, stack);
                      return const SizedBox(width: 20, height: 20);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      rebuild(() => rebuilds++);
      await tester.pumpAndSettle();
    }
    expect(errorBuilderCalls, greaterThan(1));
    expect(logger.entries, hasLength(1));
    expect(logger.entries.single.level, LogLevel.error);
    expect(logger.entries.single.stackTrace, contains('image-load-stack'));
    expect(tester.takeException(), isNull);
    rebuild(() => source = 'second');
    await tester.pumpAndSettle();
    expect(logger.entries, hasLength(2));
    expect(tester.takeException(), isNull);
  });
}

class _FailingImage extends ImageProvider<_FailingImage> {
  const _FailingImage(this.source);
  final String source;

  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    _FailingImage key,
    ImageErrorListener handleError,
  ) {
    stream.setCompleter(
      OneFrameImageStreamCompleter(
        Future<ImageInfo>.error(
          StateError('broken $source'),
          StackTrace.fromString('image-load-stack'),
        ),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _FailingImage && other.source == source;

  @override
  int get hashCode => source.hashCode;
}
