class DownloadOptions {
  const DownloadOptions({
    this.downloadHeaders,
    this.useWebViewDownload = false,
    required this.attachmentDir,
    required this.initialTab,
  });

  final Map<String, String>? downloadHeaders;
  final bool useWebViewDownload;
  final String attachmentDir;
  // 下载管理器中的初始标签页
  final int initialTab;
}
