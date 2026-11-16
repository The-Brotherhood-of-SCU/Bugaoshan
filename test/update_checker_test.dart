import 'dart:convert';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/update_checker.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/utils/release_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> release(String tag, {bool preview = true}) => {
  'tag_name': tag,
  'prerelease': preview,
};

void main() {
  group('release version precedence', () {
    final ascending = [
      '1.0.0-alpha',
      '1.0.0-alpha.1',
      '1.0.0-alpha.beta',
      '1.0.0-beta',
      '1.0.0-beta.2',
      '1.0.0-beta.11',
      '1.0.0-rc.1',
      '1.0.0',
      '1.0.1',
      '1.1.0',
      '2.0.0',
    ];
    for (int i = 1; i < ascending.length; i++) {
      test('${ascending[i]} is newer than ${ascending[i - 1]}', () {
        expect(checkHasUpdate(ascending[i - 1], ascending[i]), isTrue);
        expect(checkHasUpdate(ascending[i], ascending[i - 1]), isFalse);
      });
    }

    test('supports historical preN and rcN tags', () {
      expect(checkHasUpdate('v2.5.4-pre9', 'v2.5.4-pre12'), isTrue);
      expect(checkHasUpdate('v2.5.4-rc9', 'v2.5.4-rc10'), isTrue);
      expect(checkHasUpdate('v2.5.4-rc10', 'v2.5.4-rc.10'), isFalse);
    });

    test('promotes a preview to the stable release of the same version', () {
      expect(checkHasUpdate('2.5.4-preview.12', '2.5.4'), isTrue);
      expect(checkHasUpdate('2.5.4', '2.5.4-preview.12'), isFalse);
    });

    test('ignores build metadata and optional v prefix', () {
      expect(
        checkHasUpdate('V2.5.4-preview.12+a', '2.5.4-preview.12+b'),
        isFalse,
      );
      expect(checkHasUpdate('2.5.4+1', 'v2.5.4+2'), isFalse);
    });

    test('compares large numeric identifiers without overflowing', () {
      expect(
        checkHasUpdate(
          '2.5.4-preview.99999999999999999999',
          '2.5.4-preview.100000000000000000000',
        ),
        isTrue,
      );
    });

    test('rejects malformed versions', () {
      for (final value in [
        '',
        'null',
        '2.5',
        '2.5.4.1',
        '02.5.4',
        '2.5.4-preview.01',
        '2.5.4-preview..1',
        '2.5.4+',
        '2.5.4\n',
      ]) {
        expect(ReleaseVersion.tryParse(value), isNull, reason: value);
      }
    });
  });

  group('preview update regressions', () {
    test('preview.9 discovers preview.12', () {
      expect(
        isNewerPrerelease('v2.5.4-preview.12', '2.5.3', 'v2.5.4-preview.9'),
        isTrue,
      );
    });

    test('preview.12 never recommends preview.9', () {
      expect(
        isNewerPrerelease('v2.5.4-preview.9', '2.5.3', 'v2.5.4-preview.12'),
        isFalse,
      );
    });

    test('equal normalized tags do not produce an update', () {
      expect(
        isNewerPrerelease('v2.5.4-preview.12+new', '2.5.3', '2.5.4-preview.12'),
        isFalse,
      );
    });

    test('does not downgrade from a newer preview base version', () {
      expect(
        isNewerPrerelease('v2.5.4-preview.12', '2.5.3', 'v2.5.5-preview'),
        isFalse,
      );
    });

    test('stable builds reject previews of their installed version', () {
      expect(
        isNewerPrerelease('v2.5.4-preview.12', '2.5.4', 'v2.5.4'),
        isFalse,
      );
    });

    test('builds without git metadata still discover a higher preview', () {
      expect(isNewerPrerelease('v2.5.4-preview.12', '2.5.3', 'null'), isTrue);
      expect(isNewerPrerelease('v2.5.3-preview.12', '2.5.3', 'null'), isFalse);
    });

    test('rejects stable or invalid tags in the preview channel', () {
      expect(isNewerPrerelease('v2.5.4', '2.5.3', 'v2.5.3'), isFalse);
      expect(isNewerPrerelease('invalid', '2.5.3', 'v2.5.3'), isFalse);
    });
  });

  group('GitHub release selection', () {
    late AppLogger logger;

    setUp(() async {
      await getIt.reset();
      logger = AppLogger();
      getIt.registerSingleton<AppLogger>(logger);
    });

    tearDown(() async {
      await getIt.reset();
      logger.dispose();
    });

    test('selects .12 from the observed 9/8/12/11/10/6 order', () {
      final releases = [
        for (final number in [9, 8, 12, 11, 10, 6])
          release('v2.5.4-preview.$number'),
      ];
      expect(
        selectLatestGithubRelease(releases, prerelease: true)?['tag_name'],
        'v2.5.4-preview.12',
      );
      expect(
        selectLatestGithubRelease(
          releases.reversed,
          prerelease: true,
        )?['tag_name'],
        'v2.5.4-preview.12',
      );
    });

    test('filters drafts and malformed tags and separates tag channels', () {
      final releases = [
        {...release('v9.0.0-preview'), 'draft': true},
        release('invalid'),
        release('v2.5.1'),
        release('v2.5.4-preview.8', preview: false),
        release('v2.5.4-preview.12'),
        release('v2.5.2', preview: false),
        release('v2.5.3', preview: false),
        {'prerelease': true},
        null,
      ];
      expect(
        selectLatestGithubRelease(releases, prerelease: true)?['tag_name'],
        'v2.5.4-preview.12',
      );
      expect(
        selectLatestGithubRelease(releases, prerelease: false)?['tag_name'],
        'v2.5.3',
      );
    });

    test('uses preview tag semantics and reports a missing flag', () {
      final mislabeled = release('v2.5.4-preview', preview: false);
      final selected = selectLatestGithubRelease(
        [mislabeled],
        prerelease: true,
      );
      expect(selected?['tag_name'], 'v2.5.4-preview');
      expect(selected?['prerelease'], isTrue);
      expect(mislabeled['prerelease'], isFalse);
      expect(logger.entries.single.level, LogLevel.info);
      expect(logger.entries.single.message, contains('tag=v2.5.4-preview'));
      expect(logger.entries.single.message, contains('prerelease=false'));
      expect(logger.entries.single.message, contains('tagPrerelease=true'));
    });

    test('uses stable tag semantics and reports an extra preview flag', () {
      final selected = selectLatestGithubRelease(
        [release('v2.5.4')],
        prerelease: false,
      );
      expect(selected?['tag_name'], 'v2.5.4');
      expect(selected?['prerelease'], isFalse);
      expect(logger.entries.single.level, LogLevel.info);
      expect(logger.entries.single.message, contains('prerelease=true'));
      expect(logger.entries.single.message, contains('tagPrerelease=false'));
    });

    test('repeated checks record six info entries without deduplication', () {
      final releases = [release('v2.5.4-preview', preview: false)];
      for (int check = 0; check < 3; check++) {
        selectLatestGithubRelease(releases, prerelease: false);
        selectLatestGithubRelease(releases, prerelease: true);
      }
      expect(logger.entries, hasLength(6));
      expect(
        logger.entries.every((entry) => entry.level == LogLevel.info),
        isTrue,
      );
    });

    test('accepts a preview tag without a sequence number without warning', () {
      final selected = selectLatestGithubRelease(
        [release('v2.5.4-preview')],
        prerelease: true,
      );
      expect(selected?['tag_name'], 'v2.5.4-preview');
      expect(logger.entries, isEmpty);
    });

    test('requests 100 results once even when another page exists', () async {
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          jsonEncode([
            for (final number in [9, 8, 12, 11, 10, 6])
              release('v2.5.4-preview.$number'),
          ]),
          200,
          headers: {
            'link': '<https://api.github.com/repos/$kGithubRepo/releases'
                '?per_page=100&page=2>; rel="next"',
          },
        );
      });
      addTearDown(client.close);
      expect(
        await fetchLatestPrereleaseFromGithub(client: client),
        '2.5.4-preview.12',
      );
      expect(requests, hasLength(1));
      expect(requests.single.queryParameters, {'per_page': '100'});
    });

    test('propagates an API error without scanning more pages', () async {
      int requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('', 403);
      });
      addTearDown(client.close);
      await expectLater(
        fetchLatestPrereleaseFromGithub(client: client),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('403'),
          ),
        ),
      );
      expect(requests, 1);
    });
  });
}
