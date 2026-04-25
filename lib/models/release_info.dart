class ReleaseInfo {
  final String? version;
  final String? downloadUrl;
  final bool isPrerelease;

  const ReleaseInfo({
    this.version,
    this.downloadUrl,
    this.isPrerelease = false,
  });
}