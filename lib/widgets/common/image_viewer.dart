import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/share_utils.dart';

void showFullScreenImageViewer(
  BuildContext context, {
  required String imageUrl,
  Map<String, String>? headers,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ImageViewerPage(imageUrl: imageUrl, headers: headers),
    ),
  );
}

class ImageViewerPage extends StatelessWidget {
  final String imageUrl;
  final Map<String, String>? headers;

  const ImageViewerPage({super.key, required this.imageUrl, this.headers});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: GestureDetector(
              onLongPress: () => _showActions(context, l10n),
              child: PhotoView(
                imageProvider: NetworkImage(imageUrl, headers: headers),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
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
              onPressed: () => _showActions(context, l10n),
            ),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context, AppLocalizations l10n) {
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
                _saveToGallery(context, l10n);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(l10n.share),
              onTap: () {
                Navigator.pop(ctx);
                _share(context, l10n);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToGallery(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    try {
      final response = await http.get(Uri.parse(imageUrl), headers: headers);
      if (response.statusCode != 200) throw Exception('Download failed');
      await Gal.putImageBytes(response.bodyBytes);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.imageSavedToGallery)));
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

  Future<void> _share(BuildContext context, AppLocalizations l10n) async {
    try {
      final response = await http.get(Uri.parse(imageUrl), headers: headers);
      if (response.statusCode != 200) throw Exception('Download failed');
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/shared_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(response.bodyBytes);
      await shareSingleFile(file.path);
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
}
