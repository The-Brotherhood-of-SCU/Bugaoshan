enum UpdateAssetPlatform { android, windows, linux }

bool _matchesUpdatePlatform(String assetName, UpdateAssetPlatform platform) {
  final name = assetName.toLowerCase();
  return switch (platform) {
    UpdateAssetPlatform.android => name.endsWith('_universal.apk'),
    UpdateAssetPlatform.windows =>
      name.contains('_windows_') && name.endsWith('.zip'),
    UpdateAssetPlatform.linux =>
      name.contains('_linux_') && name.endsWith('.tar.gz'),
  };
}

Map<String, dynamic>? selectUpdateAsset(
  Iterable<Map<String, dynamic>> assets,
  UpdateAssetPlatform platform,
) {
  for (final asset in assets) {
    final name = asset['name'];
    if (name is String && _matchesUpdatePlatform(name, platform)) {
      return asset;
    }
  }
  return null;
}
