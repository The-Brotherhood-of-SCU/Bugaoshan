import 'dart:convert';

import 'package:bugaoshan/services/github_resource_service.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> release(String tag, {bool preview = true}) => {
  'tag_name': tag,
  'prerelease': preview,
  'body': 'Notes for $tag',
  'assets': [
    for (final suffix in [
      'windows_x64.zip',
      'linux_x64.tar.gz',
      'universal.apk',
    ])
      {
        'name': 'bugaoshan_${tag}_$suffix',
        'browser_download_url': 'https://example.com/$tag/$suffix',
        'digest': 'sha256:test-checksum',
      },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UpdateService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    service = UpdateService(
      prefs,
      '2.5.3',
      GithubResourceService(useProxy: () => true),
    );
  });

  test(
    'production preview check selects .12 with its own assets and notes',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode([
            for (final number in [9, 8, 12, 11, 10, 6])
              release('v2.5.4-preview.$number'),
          ]),
          200,
        ),
      );
      addTearDown(client.close);
      final latest = await http.runWithClient(
        service.getLatestPrereleaseFromGitHub,
        () => client,
      );
      expect(latest.tagName, 'v2.5.4-preview.12');
      expect(latest.downloadUrl, contains('/v2.5.4-preview.12/'));
      expect(latest.body, 'Notes for v2.5.4-preview.12');
      expect(latest.checksumSha256, 'test-checksum');
    },
  );

  test('keeps stable inside a 62-release window with one request', () async {
    final releases = [
      for (int number = 48; number >= 1; number--)
        release('v2.5.4-preview.$number'),
      release('v2.5.3', preview: false),
      for (int number = 0; number < 13; number++)
        release('v2.0.$number', preview: false),
    ];
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      expect(request.url.path, isNot(endsWith('/latest')));
      final perPage = request.url.queryParameters['per_page'] ?? '30';
      return http.Response(
        jsonEncode(releases.take(int.parse(perPage)).toList()),
        200,
      );
    });
    addTearDown(client.close);
    final (stable, preview) = await http.runWithClient(
      service.getAllLatestReleases,
      () => client,
    );
    expect(stable?.tagName, 'v2.5.3');
    expect(preview?.tagName, 'v2.5.4-preview.48');
    expect(requests, hasLength(1));
    expect(requests.single.queryParameters['per_page'], '100');
  });

  test(
    'preview checks reject an older candidate even with the old package version',
    () async {
      final client = MockClient(
        (_) async =>
            http.Response(jsonEncode([release('v2.5.4-preview.9')]), 200),
      );
      addTearDown(client.close);
      final result = await http.runWithClient(
        () => service.checkPreviewUpdate('2.5.3', 'v2.5.4-preview.12'),
        () => client,
      );
      expect(result.noUpdate, isTrue);
    },
  );

  test(
    'uses the stable endpoint when the list contains only previews',
    () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/latest')
                ? release('v2.5.3', preview: false)
                : [release('v2.5.4-preview.12')],
          ),
          200,
        );
      });
      addTearDown(client.close);
      final (stable, preview) = await http.runWithClient(
        service.getAllLatestReleases,
        () => client,
      );
      expect(stable?.tagName, 'v2.5.3');
      expect(preview?.tagName, 'v2.5.4-preview.12');
      expect(paths.last, endsWith('/releases/latest'));
    },
  );

  test('service results use tag channels when API flags disagree', () async {
    final client = MockClient((_) async => http.Response(
      jsonEncode([
        {...release('v2.5.4', preview: false), 'prerelease': true},
        {...release('v2.5.5-preview'), 'prerelease': false},
      ]),
      200,
    ));
    addTearDown(client.close);
    final (stable, preview) = await http.runWithClient(
      service.getAllLatestReleases,
      () => client,
    );
    expect(stable?.tagName, 'v2.5.4');
    expect(stable?.isPrerelease, isFalse);
    expect(preview?.tagName, 'v2.5.5-preview');
    expect(preview?.isPrerelease, isTrue);
  });

  test('list and latest paths reject a stable release without assets', () async {
    final missing = {...release('v2.5.4', preview: false), 'assets': []};
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response(
        jsonEncode(request.url.path.endsWith('/latest') ? missing : [missing]),
        200,
      );
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      expect(await service.getLatestReleaseFromGitHub(), isNull);
      final (stable, preview) = await service.getAllLatestReleases();
      expect(stable, isNull);
      expect(preview, isNull);
      expect(requests, hasLength(2));
      expect(requests.last.path, endsWith('/releases'));
      expect((await service.checkStableUpdate('2.5.3')).noUpdate, isTrue);
    }, () => client);
  });

  test('preview without platform assets is not an installable update', () async {
    final client = MockClient((_) async => http.Response(
      jsonEncode([
        release('v2.5.3', preview: false),
        {...release('v2.5.4-preview.12'), 'assets': []},
      ]),
      200,
    ));
    addTearDown(client.close);
    await http.runWithClient(() async {
      final latest = await service.getLatestPrereleaseFromGitHub();
      expect(latest.tagName, isNull);
      expect(latest.downloadUrl, isNull);
      final (stable, preview) = await service.getAllLatestReleases();
      expect(stable?.tagName, 'v2.5.3');
      expect(preview, isNull);
      final result = await service.checkPreviewUpdate('2.5.3', 'v2.5.3');
      expect(result.noUpdate, isTrue);
    }, () => client);
  });

  test('matching assets without download URLs are not usable updates', () async {
    final invalid = release('v2.5.4', preview: false);
    for (final asset in invalid['assets'] as List<dynamic>) {
      asset['browser_download_url'] = '';
    }
    final client = MockClient((request) async => http.Response(
      jsonEncode(request.url.path.endsWith('/latest') ? invalid : [invalid]),
      200,
    ));
    addTearDown(client.close);
    await http.runWithClient(() async {
      expect(await service.getLatestReleaseFromGitHub(), isNull);
      final (stable, preview) = await service.getAllLatestReleases();
      expect(stable, isNull);
      expect(preview, isNull);
    }, () => client);
  });

  test('latest endpoint cannot introduce a mislabeled preview to stable', () async {
    final client = MockClient((_) async => http.Response(
      jsonEncode(release('v2.5.4-preview', preview: false)),
      200,
    ));
    addTearDown(client.close);
    final result = await http.runWithClient(
      () => service.checkStableUpdate('2.5.3'),
      () => client,
    );
    expect(result.noUpdate, isTrue);
  });

  test('newest candidates without packages never fall back to older assets', () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response(
        jsonEncode([
          release('v2.5.4', preview: false),
          {...release('v2.5.5', preview: false), 'assets': []},
          release('v2.5.6-preview.9'),
          {...release('v2.5.6-preview.12'), 'assets': []},
        ]),
        200,
      );
    });
    addTearDown(client.close);
    final (stable, preview) = await http.runWithClient(
      service.getAllLatestReleases,
      () => client,
    );
    expect(stable, isNull);
    expect(preview, isNull);
    expect(requests, hasLength(1));
    expect(requests.single.path, endsWith('/releases'));
  });
}
