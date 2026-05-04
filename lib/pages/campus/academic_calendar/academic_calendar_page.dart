import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;

class _CalendarEntry {
  final String title;
  final String path;

  const _CalendarEntry({required this.title, required this.path});
}

class AcademicCalendarPage extends StatefulWidget {
  const AcademicCalendarPage({super.key});

  @override
  State<AcademicCalendarPage> createState() => _AcademicCalendarPageState();
}

class _AcademicCalendarPageState extends State<AcademicCalendarPage> {
  static const _base = 'https://jwc.scu.edu.cn';

  bool _loading = true;
  String? _error;
  List<_CalendarEntry> _entries = [];
  List<String> _imageUrls = [];
  _CalendarEntry? _selected;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await http.get(Uri.parse('$_base/cdxl.htm'));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final body = latin1.decode(resp.bodyBytes);
      final entries = <_CalendarEntry>[];
      final linkReg = RegExp(
        r'<a[^>]+href="(info/1101/\d+\.htm)"[^>]*>[^<]*?(\d{4})-(\d{4})[^<]*</a>',
      );
      for (final match in linkReg.allMatches(body)) {
        entries.add(
          _CalendarEntry(
            title: '${match.group(2)}-${match.group(3)}',
            path: match.group(1)!,
          ),
        );
      }

      if (entries.isEmpty) {
        throw Exception('No calendar entries found');
      }

      setState(() {
        _entries = entries;
        _selected = entries.first;
      });

      await _loadDetail(entries.first);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadDetail(_CalendarEntry entry) async {
    setState(() {
      _loading = true;
      _error = null;
      _imageUrls = [];
    });

    try {
      final resp = await http.get(Uri.parse('$_base/${entry.path}'));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final body = latin1.decode(resp.bodyBytes);
      final imgReg = RegExp(
        r'<img[^>]+src="(/__local/[^"]+\.(?:jpg|jpeg|png|gif|webp))"[^>]*>',
        caseSensitive: false,
      );
      final urls = <String>[];
      for (final match in imgReg.allMatches(body)) {
        urls.add('$_base${match.group(1)}');
      }

      if (urls.isEmpty) {
        throw Exception('No images found');
      }

      if (mounted) {
        setState(() {
          _imageUrls = urls;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.academicCalendar)),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_error != null && _entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadList,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.gradesRetry),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_entries.isNotEmpty) _buildSelector(l10n),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _imageUrls.isEmpty
              ? Center(child: Text(l10n.noData))
              : _buildImageList(l10n),
        ),
      ],
    );
  }

  Widget _buildSelector(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<_CalendarEntry>(
        initialValue: _selected,
        decoration: InputDecoration(
          labelText: l10n.selectAcademicYear,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: _entries.map((e) {
          return DropdownMenuItem(value: e, child: Text(e.title));
        }).toList(),
        onChanged: (entry) {
          if (entry != null && entry != _selected) {
            setState(() => _selected = entry);
            _loadDetail(entry);
          }
        },
      ),
    );
  }

  Widget _buildImageList(AppLocalizations l10n) {
    final isMobile =
        !kIsWeb &&
        defaultTargetPlatform != TargetPlatform.windows &&
        defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.linux;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _imageUrls.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < _imageUrls.length - 1 ? 12 : 0,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              scaleEnabled: isMobile,
              panEnabled: isMobile,
              maxScale: 5,
              child: Image.network(
                _imageUrls[index],
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
                          style: TextStyle(
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
