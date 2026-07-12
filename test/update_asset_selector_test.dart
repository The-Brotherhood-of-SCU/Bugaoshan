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

  test('Android selects the universal APK even when splits come first', () {
    final selected = selectUpdateAsset([
      ...splitAssets,
      {
        'name': 'bugaoshan_2.2.0_universal.apk',
        'browser_download_url': 'https://example.com/universal.apk',
      },
    ], UpdateAssetPlatform.android);

    expect(selected?['name'], 'bugaoshan_2.2.0_universal.apk');
  });

  test('Android never falls back to an ABI split APK', () {
    final selected = selectUpdateAsset(
      splitAssets,
      UpdateAssetPlatform.android,
    );

    expect(selected, isNull);
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
