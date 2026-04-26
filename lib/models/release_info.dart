class ReleaseInfo {
  final String? tagName;
  final String? downloadUrl;
  final bool isPrerelease;

  const ReleaseInfo({
    this.tagName,
    this.downloadUrl,
    this.isPrerelease = false,
  });
}