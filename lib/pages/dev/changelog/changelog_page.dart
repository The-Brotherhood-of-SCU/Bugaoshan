import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/dev/changelog/changelog_version_page.dart';

class _VersionEntry {
  final String version;
  final String? date;
  final String content;

  const _VersionEntry({
    required this.version,
    this.date,
    required this.content,
  });
}

class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  List<_VersionEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChangelog();
  }

  Future<void> _loadChangelog() async {
    try {
      final raw = await rootBundle.loadString('CHANGELOG.md');
      if (mounted) {
        setState(() {
          _entries = _parseVersions(raw);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  static List<_VersionEntry> _parseVersions(String raw) {
    final entries = <_VersionEntry>[];
    final lines = raw.split('\n');
    int? start;
    String? currentVersion;
    String? currentDate;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final headerMatch = RegExp(
        r'^##\s+\[(.+?)\](?:\s*-\s*(.+))?$',
      ).matchAsPrefix(line);
      if (headerMatch != null) {
        if (currentVersion != null && start != null) {
          entries.add(
            _VersionEntry(
              version: currentVersion,
              date: currentDate,
              content: lines.sublist(start, i).join('\n').trim(),
            ),
          );
        }
        currentVersion = headerMatch.group(1)!;
        currentDate = headerMatch.group(2)?.trim();
        start = i + 1;
      }
    }
    if (currentVersion != null && start != null) {
      entries.add(
        _VersionEntry(
          version: currentVersion,
          date: currentDate,
          content: lines.sublist(start).join('\n').trim(),
        ),
      );
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.changelog)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final isUnreleased = entry.version == 'Unreleased';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isUnreleased
                        ? theme.colorScheme.tertiaryContainer
                        : theme.colorScheme.primaryContainer,
                    child: Icon(
                      isUnreleased ? Icons.edit_note : Icons.newspaper,
                      color: isUnreleased
                          ? theme.colorScheme.onTertiaryContainer
                          : theme.colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    isUnreleased ? localizations.unreleased : entry.version,
                  ),
                  subtitle: entry.date != null
                      ? Text(entry.date!, style: theme.textTheme.bodySmall)
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangelogVersionPage(
                        version: entry.version,
                        date: entry.date,
                        content: entry.content,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
