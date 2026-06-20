class ReleaseInfo {
  final String? tagName;
  final String? downloadUrl;
  final String? checksumSha256;
  final bool isPrerelease;
  final String? body;

  const ReleaseInfo({
    this.tagName,
    this.downloadUrl,
    this.checksumSha256,
    this.isPrerelease = false,
    this.body,
  });
}
