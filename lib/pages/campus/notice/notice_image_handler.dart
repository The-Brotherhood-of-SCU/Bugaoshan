part of 'campus_notice_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Image display, full-screen viewer, save & share (top-level functions)
// ═══════════════════════════════════════════════════════════════════════════════

Widget _buildNoticeImage(BuildContext context, String imageUrl) {
  return GestureDetector(
    onTap: () => _showFullScreenImage(context, imageUrl),
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

void _showFullScreenImage(BuildContext context, String imageUrl) {
  final l10n = AppLocalizations.of(context)!;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: GestureDetector(
                onLongPress: () => _showImageActions(context, imageUrl, l10n),
                child: PhotoView(
                  imageProvider: NetworkImage(
                    imageUrl,
                    headers: _NoticeHttp._buildHeaders(),
                  ),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.white54,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () => _showImageActions(context, imageUrl, l10n),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showImageActions(
  BuildContext context,
  String imageUrl,
  AppLocalizations l10n,
) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(l10n.saveImageToGallery),
            onTap: () {
              Navigator.pop(ctx);
              _saveImageToGallery(context, imageUrl, l10n);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: Text(l10n.share),
            onTap: () {
              Navigator.pop(ctx);
              _shareImage(context, imageUrl, l10n);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _saveImageToGallery(
  BuildContext context,
  String imageUrl,
  AppLocalizations l10n,
) async {
  try {
    final response = await http.get(
      Uri.parse(imageUrl),
      headers: _NoticeHttp._buildHeaders(),
    );
    if (response.statusCode != 200) throw Exception('Download failed');
    await Gal.putImageBytes(response.bodyBytes);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.imageSavedToGallery)),
      );
    }
  } catch (e) {
    debugPrint('Save image error: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.imageSaveFailed),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _shareImage(
  BuildContext context,
  String imageUrl,
  AppLocalizations l10n,
) async {
  try {
    final response = await http.get(
      Uri.parse(imageUrl),
      headers: _NoticeHttp._buildHeaders(),
    );
    if (response.statusCode != 200) throw Exception('Download failed');
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/notice_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(response.bodyBytes);
    await Share.shareXFiles([XFile(file.path)]);
  } catch (e) {
    debugPrint('Share image error: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.imageSaveFailed),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
