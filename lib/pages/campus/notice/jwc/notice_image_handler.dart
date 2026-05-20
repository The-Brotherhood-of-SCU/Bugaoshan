part of 'campus_notice_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Image display and full-screen viewer (top-level functions)
// ═══════════════════════════════════════════════════════════════════════════════

Widget _buildNoticeImage(BuildContext context, String imageUrl) {
  return GestureDetector(
    onTap: () => showFullScreenImageViewer(
      context,
      imageUrl: imageUrl,
      headers: _NoticeHttp._buildHeaders(),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        fit: BoxFit.fitWidth,
        headers: _NoticeHttp._buildHeaders(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 200,
            alignment: Alignment.center,
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.loadFailed,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
