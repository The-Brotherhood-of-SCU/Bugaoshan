class ReleaseInfo {
  final String? tagName;
  final String? downloadUrl;
  final bool isPrerelease;
  final String? body;

  const ReleaseInfo({
    this.tagName,
    this.downloadUrl,
    this.isPrerelease = false,
    this.body,
  });
}
