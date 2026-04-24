class ReleaseInfo {
  final String version;
  final String? downloadUrl;
  final bool isPrerelease;

  const ReleaseInfo({
    required this.version,
    this.downloadUrl,
    this.isPrerelease = false,
  });
}