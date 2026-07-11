import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/academic_calendar.dart';
import 'package:bugaoshan/services/api/academic_calendar_service.dart';
import 'package:bugaoshan/utils/calendar_export_utils.dart';

import 'official_calendar_view.dart';
import 'interactive_calendar_view.dart';

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
  List<CalendarEntry> _entries = [];
  List<String> _imageUrls = [];
  CalendarEntry? _selected;

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
      final resp = await http
          .get(Uri.parse('$_base/cdxl.htm'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final body = latin1.decode(resp.bodyBytes);
      final entries = <CalendarEntry>[];
      final linkReg = RegExp(
        r'<a[^>]+href="(info/1101/\d+\.htm)"[^>]*>[^<]*?(\d{4})-(\d{4})[^<]*</a>',
      );
      for (final match in linkReg.allMatches(body)) {
        entries.add(
          CalendarEntry(
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

  Future<void> _loadDetail(CalendarEntry entry) async {
    setState(() {
      _loading = true;
      _error = null;
      _imageUrls = [];
    });

    try {
      final resp = await http
          .get(Uri.parse('$_base/${entry.path}'))
          .timeout(const Duration(seconds: 8));
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
          InteractiveCalendarView(
            data: _interactiveData,
            selectedSemester: _selectedSemester,
            loading: _interactiveLoading,
            error: _interactiveError,
            onSemesterChanged: (semester) {
              setState(() => _selectedSemester = semester);
            },
            onRetry: _loadInteractiveData,
          ),
          OfficialCalendarView(
            entries: _entries,
            selected: _selected,
            loading: _loading,
            error: _error,
            imageUrls: _imageUrls,
            onEntryChanged: (entry) {
              setState(() => _selected = entry);
              _loadDetail(entry);
            },
            onRetry: _loadList,
          ),
        ],
      ),
    );
  }
}
