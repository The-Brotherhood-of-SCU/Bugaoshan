import 'package:bugaoshan/services/update_asset_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const splitAssets = [
    {
      'name': 'bugaoshan_2.2.0_arm64-v8a.apk',
      'browser_download_url': 'https://example.com/arm64.apk',
    },
    {
      'name': 'bugaoshan_2.2.0_armeabi-v7a.apk',
      'browser_download_url': 'https://example.com/armv7.apk',
    },
    {
      'name': 'bugaoshan_2.2.0_x86_64.apk',
      'browser_download_url': 'https://example.com/x64.apk',
    },
  ];

  group('Android without androidArch parameter', () {
    test('selects the universal APK even when splits come first', () {
      final selected = selectUpdateAsset([
        ...splitAssets,
        {
          'name': 'bugaoshan_2.2.0_universal.apk',
          'browser_download_url': 'https://example.com/universal.apk',
        },
      ], UpdateAssetPlatform.android);

      expect(selected?['name'], 'bugaoshan_2.2.0_universal.apk');
    });

    test('returns null when only split APKs are available', () {
      final selected = selectUpdateAsset(
        splitAssets,
        UpdateAssetPlatform.android,
      );

      expect(selected, isNull);
    });
  });

  group('Android with androidArch parameter', () {
    test('selects arm64-v8a APK when device is arm64-v8a', () {
      final selected = selectUpdateAsset(
        [
          {
            'name': 'bugaoshan_2.2.0_universal.apk',
            'browser_download_url': 'https://example.com/universal.apk',
          },
          ...splitAssets,
        ],
        UpdateAssetPlatform.android,
        androidArch: 'arm64-v8a',
      );

      expect(selected?['name'], 'bugaoshan_2.2.0_arm64-v8a.apk');
    });

    test('selects armeabi-v7a APK when device is armeabi-v7a', () {
      final selected = selectUpdateAsset(
        [
          ...splitAssets,
          {
            'name': 'bugaoshan_2.2.0_universal.apk',
            'browser_download_url': 'https://example.com/universal.apk',
          },
        ],
        UpdateAssetPlatform.android,
        androidArch: 'armeabi-v7a',
      );

      expect(selected?['name'], 'bugaoshan_2.2.0_armeabi-v7a.apk');
    });

    test('falls back to universal when arch-specific APK is missing', () {
      final selected = selectUpdateAsset(
        [
          {
            'name': 'bugaoshan_2.2.0_universal.apk',
            'browser_download_url': 'https://example.com/universal.apk',
          },
          {
            'name': 'bugaoshan_2.2.0_arm64-v8a.apk',
            'browser_download_url': 'https://example.com/arm64.apk',
          },
        ],
        UpdateAssetPlatform.android,
        androidArch: 'x86_64', // x86_64 not in assets
      );

      expect(selected?['name'], 'bugaoshan_2.2.0_universal.apk');
    });

    test('returns null when neither arch nor universal APK exists', () {
      final selected = selectUpdateAsset(
        [
          {
            'name': 'bugaoshan_2.2.0_arm64-v8a.apk',
            'browser_download_url': 'https://example.com/arm64.apk',
          },
        ],
        UpdateAssetPlatform.android,
        androidArch: 'x86_64',
      );

      expect(selected, isNull);
    });
  });

  test('desktop platforms retain their archive selection', () {
    const assets = [
      {'name': 'bugaoshan_2.2.0_linux_x64.tar.gz'},
      {'name': 'bugaoshan_2.2.0_windows_x64.zip'},
    ];

    expect(
      selectUpdateAsset(assets, UpdateAssetPlatform.windows)?['name'],
      'bugaoshan_2.2.0_windows_x64.zip',
    );
    expect(
      selectUpdateAsset(assets, UpdateAssetPlatform.linux)?['name'],
      'bugaoshan_2.2.0_linux_x64.tar.gz',
    );
  });
}
