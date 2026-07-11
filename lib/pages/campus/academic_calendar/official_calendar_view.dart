import 'package:flutter/material.dart';
import 'package:bugaoshan/utils/app_shapes.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/image_viewer.dart';

class CalendarEntry {
  final String title;
  final String path;

  const CalendarEntry({required this.title, required this.path});
}

class OfficialCalendarView extends StatelessWidget {
  final List<CalendarEntry> entries;
  final CalendarEntry? selected;
  final bool loading;
  final String? error;
  final List<String> imageUrls;
  final ValueChanged<CalendarEntry> onEntryChanged;
  final VoidCallback onRetry;

  const OfficialCalendarView({
    super.key,
    required this.entries,
    this.selected,
    required this.loading,
    this.error,
    required this.imageUrls,
    required this.onEntryChanged,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (error != null && entries.isEmpty) {
      return RetryableErrorWidget(
        errorType: LoadErrorType.loadFailed,
        onRetry: onRetry,
      );
    }

    return Column(
      children: [
        if (entries.isNotEmpty) _buildOfficialSelector(l10n),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : imageUrls.isEmpty
              ? Center(child: Text(l10n.noData))
              : _buildImageList(l10n),
        ),
      ],
    );
  }

  Widget _buildOfficialSelector(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<CalendarEntry>(
        initialValue: selected,
        decoration: InputDecoration(
          labelText: l10n.selectAcademicYear,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: entries.map((e) {
          return DropdownMenuItem(value: e, child: Text(e.title));
        }).toList(),
        onChanged: (entry) {
          if (entry != null && entry != selected) {
            onEntryChanged(entry);
          }
        },
      ),
    );
  }

  Widget _buildImageList(AppLocalizations l10n) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: imageUrls.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < imageUrls.length - 1 ? 12 : 0,
          ),
          child: GestureDetector(
            onTap: () =>
                showFullScreenImageViewer(context, imageUrl: imageUrls[index]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppShapes.medium),
              child: Image.network(
                imageUrls[index],
                fit: BoxFit.fitWidth,
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
                          l10n.loadFailed,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
