import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:bugaoshan/utils/app_shapes.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/image_viewer.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/academic_calendar.dart';
import 'package:bugaoshan/services/api/academic_calendar_service.dart';
import 'package:bugaoshan/utils/calendar_export_utils.dart';

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

class _AcademicCalendarPageState extends State<AcademicCalendarPage>
    with SingleTickerProviderStateMixin {
  static const _base = 'https://jwc.scu.edu.cn';

  late TabController _tabController;

  // Official Chart variables
  bool _loading = true;
  String? _error;
  List<_CalendarEntry> _entries = [];
  List<String> _imageUrls = [];
  _CalendarEntry? _selected;

  // Interactive Calendar variables
  bool _interactiveLoading = true;
  String? _interactiveError;
  AcademicCalendarData? _interactiveData;
  AcademicCalendarSemester? _selectedSemester;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadList();
    _loadInteractiveData();
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // Fetch official calendar list (images)
  Future<void> _loadList() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await http.get(Uri.parse('$_base/cdxl.htm')).timeout(const Duration(seconds: 8));
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
      final resp = await http.get(Uri.parse('$_base/${entry.path}')).timeout(const Duration(seconds: 8));
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

  // Fetch interactive calendar data
  Future<void> _loadInteractiveData() async {
    setState(() {
      _interactiveLoading = true;
      _interactiveError = null;
    });

    try {
      final service = getIt<AcademicCalendarService>();
      final data = await service.fetchCalendarData();

      AcademicCalendarSemester? initialSemester;
      final now = DateTime.now();
      for (final semester in data.semesters) {
        if (semester.isDateInSemester(now)) {
          initialSemester = semester;
          break;
        }
      }

      if (initialSemester == null && data.semesters.isNotEmpty) {
        initialSemester = data.semesters.first;
      }

      if (mounted) {
        setState(() {
          _interactiveData = data;
          _selectedSemester = initialSemester;
          _interactiveLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _interactiveError = e.toString();
          _interactiveLoading = false;
        });
      }
    }
  }

  Future<void> _importSemesterToSystem() async {
    if (_selectedSemester == null) return;
    final l10n = AppLocalizations.of(context)!;
    final service = getIt<AcademicCalendarService>();

    final action = await CalendarExportUtils.showActionSheet(
      context,
      l10n,
      title: l10n.calendarImportCalendarTitle,
      includeCopy: false,
    );

    if (action == null || !mounted) return;

    await CalendarExportUtils.handleExportAction(
      context: context,
      l10n: l10n,
      action: action,
      copyToClipboard: () async => false,
      copySuccessMessage: '',
      copyFailedMessage: '',
      buildCalendarPayload: () => service.genExportPayload(_selectedSemester!),
      logTag: 'AcademicCalendarPage',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.academicCalendar),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.interactiveCalendar),
            Tab(text: l10n.originalCalendar),
          ],
        ),
        actions: [
          if (_tabController.index == 0 && _selectedSemester != null)
            IconButton(
              icon: const Icon(Icons.event_available),
              tooltip: l10n.calendarImportButton,
              onPressed: _importSemesterToSystem,
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInteractiveView(l10n),
          _buildOfficialChartsView(l10n),
        ],
      ),
    );
  }

  // --- Official Charts View ---
  Widget _buildOfficialChartsView(AppLocalizations l10n) {
    if (_error != null && _entries.isEmpty) {
      return RetryableErrorWidget(
        errorType: LoadErrorType.loadFailed,
        onRetry: _loadList,
      );
    }

    return Column(
      children: [
        if (_entries.isNotEmpty) _buildOfficialSelector(l10n),
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

  Widget _buildOfficialSelector(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<_CalendarEntry>(
        value: _selected,
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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _imageUrls.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < _imageUrls.length - 1 ? 12 : 0,
          ),
          child: GestureDetector(
            onTap: () =>
                showFullScreenImageViewer(context, imageUrl: _imageUrls[index]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppShapes.medium),
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

  // --- Interactive Calendar View ---
  Widget _buildInteractiveView(AppLocalizations l10n) {
    if (_interactiveLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_interactiveError != null && _interactiveData == null) {
      return RetryableErrorWidget(
        errorType: LoadErrorType.loadFailed,
        onRetry: _loadInteractiveData,
      );
    }

    if (_interactiveData == null || _interactiveData!.semesters.isEmpty) {
      return Center(child: Text(l10n.calendarNoEventData));
    }

    return Column(
      children: [
        _buildInteractiveSelector(l10n),
        if (_selectedSemester != null) ...[
          _buildSemesterHeaderCard(l10n, _selectedSemester!),
          Expanded(child: _buildTimeline(l10n, _selectedSemester!)),
        ],
      ],
    );
  }

  Widget _buildInteractiveSelector(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<AcademicCalendarSemester>(
        value: _selectedSemester,
        decoration: InputDecoration(
          labelText: l10n.selectAcademicYear,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: _interactiveData!.semesters.map((s) {
          return DropdownMenuItem(value: s, child: Text(s.name));
        }).toList(),
        onChanged: (semester) {
          if (semester != null && semester != _selectedSemester) {
            setState(() => _selectedSemester = semester);
          }
        },
      ),
    );
  }

  Widget _buildSemesterHeaderCard(AppLocalizations l10n, AcademicCalendarSemester semester) {
    final now = DateTime.now();
    final currentWeek = semester.getCurrentWeek(now);
    final isCurrent = semester.isDateInSemester(now);

    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.primaryContainer;
    final onCardColor = theme.colorScheme.onPrimaryContainer;

    // Find next upcoming event
    AcademicCalendarEvent? nextEvent;
    for (final event in semester.events) {
      if (!event.isFinished(now) && !event.isActive(now)) {
        if (nextEvent == null || event.date.isBefore(nextEvent.date)) {
          nextEvent = event;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    semester.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onCardColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isCurrent && currentWeek != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppShapes.extraLarge),
                    ),
                    child: Text(
                      l10n.calendarCurrentWeek(currentWeek),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.calendarSemesterStart(DateFormat('yyyy-MM-dd').format(semester.startDate)) +
                  ' (${l10n.calendarWeeksTotal(semester.totalWeeks)})',
              style: theme.textTheme.bodyMedium?.copyWith(color: onCardColor.withOpacity(0.85)),
            ),
            if (nextEvent != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 16, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.calendarNextEvent}: ${nextEvent.label}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onCardColor,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    l10n.calendarDaysRemaining(nextEvent.getDaysDifference(now)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onCardColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(AppLocalizations l10n, AcademicCalendarSemester semester) {
    final now = DateTime.now();

    // Sort events by date
    final sortedEvents = List<AcademicCalendarEvent>.from(semester.events)
      ..sort((a, b) => a.date.compareTo(b.date));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: sortedEvents.length,
      itemBuilder: (context, index) {
        final event = sortedEvents[index];
        final isLast = index == sortedEvents.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column: Dot & Line
              _buildTimelineIndicator(context, event, isLast, now),
              // Right Column: Card Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 16),
                  child: _buildEventCard(context, l10n, event, now),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineIndicator(
      BuildContext context, AcademicCalendarEvent event, bool isLast, DateTime now) {
    final theme = Theme.of(context);
    final isActive = event.isActive(now);
    final isPast = event.isFinished(now);

    Color color;
    if (isActive) {
      color = theme.colorScheme.primary;
    } else if (isPast) {
      color = theme.colorScheme.outlineVariant;
    } else {
      color = _getTagColor(theme, event.tag);
    }

    return SizedBox(
      width: 24,
      child: Column(
        children: [
          // Dot
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isActive ? Colors.transparent : color,
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: isActive ? 4 : 2,
              ),
            ),
          ),
          // Line
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
      BuildContext context, AppLocalizations l10n, AcademicCalendarEvent event, DateTime now) {
    final theme = Theme.of(context);
    final isActive = event.isActive(now);
    final isPast = event.isFinished(now);

    final tagBg = _getTagBgColor(theme, event.tag);
    final tagText = _getTagTextColor(theme, event.tag);

    // Format dates
    final dateStr = DateFormat('MM/dd').format(event.date);
    final endDateStr = event.endDate != null ? DateFormat('MM/dd').format(event.endDate!) : null;
    final fullDateRange = endDateStr != null ? '$dateStr - $endDateStr' : dateStr;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.medium),
        side: isActive
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Left content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Event Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(AppShapes.small),
                        ),
                        child: Text(
                          _getTagLabel(l10n, event.tag),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tagText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Date range text
                      Text(
                        fullDateRange,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isPast ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isPast ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Right countdown text
            const SizedBox(width: 8),
            _buildCountdownWidget(l10n, theme, event, now, isActive, isPast),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownWidget(AppLocalizations l10n, ThemeData theme,
      AcademicCalendarEvent event, DateTime now, bool isActive, bool isPast) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppShapes.medium),
        ),
        child: Text(
          l10n.calendarToday,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (isPast) {
      final days = -event.getDaysDifference(now);
      return Text(
        l10n.calendarStartedNDaysAgo(days),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    } else {
      final days = event.getDaysDifference(now);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppShapes.medium),
        ),
        child: Text(
          l10n.calendarDaysRemaining(days),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  String _getTagLabel(AppLocalizations l10n, String tag) {
    switch (tag) {
      case 'holiday':
        return l10n.calendarHolidayTag;
      case 'exam':
        return l10n.calendarExamTag;
      case 'start':
        return l10n.calendarStartTag;
      default:
        return l10n.calendarEventTag;
    }
  }

  Color _getTagColor(ThemeData theme, String tag) {
    switch (tag) {
      case 'holiday':
        return theme.colorScheme.tertiary;
      case 'exam':
        return theme.colorScheme.error;
      case 'start':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.secondary;
    }
  }

  Color _getTagBgColor(ThemeData theme, String tag) {
    switch (tag) {
      case 'holiday':
        return theme.colorScheme.tertiaryContainer;
      case 'exam':
        return theme.colorScheme.errorContainer;
      case 'start':
        return theme.colorScheme.primaryContainer;
      default:
        return theme.colorScheme.secondaryContainer;
    }
  }

  Color _getTagTextColor(ThemeData theme, String tag) {
    switch (tag) {
      case 'holiday':
        return theme.colorScheme.onTertiaryContainer;
      case 'exam':
        return theme.colorScheme.onErrorContainer;
      case 'start':
        return theme.colorScheme.onPrimaryContainer;
      default:
        return theme.colorScheme.onSecondaryContainer;
    }
  }
}
