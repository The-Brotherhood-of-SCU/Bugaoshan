import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/class_schedule_inquiry/class_schedule_inquiry_detail_page.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';

class ClassScheduleInquiryPage extends StatefulWidget {
  const ClassScheduleInquiryPage({super.key});

  @override
  State<ClassScheduleInquiryPage> createState() =>
      _ClassScheduleInquiryPageState();
}

class _ClassScheduleInquiryPageState extends State<ClassScheduleInquiryPage> {
  late final ZhjwApiService _zhjwApi;

  // 班级数据
  List<ClassInfo> _classes = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _pageNum = 1;
  static const int _pageSize = 30;
  String? _error;

  // 筛选选项
  List<SemesterOption> _semesters = [];
  List<String> _grades = [];
  List<DepartmentOption> _departments = [];
  List<SubjectOption> _subjects = [];
  List<ClassOption> _classOptions = [];

  // 筛选状态
  bool _isLoadingIndex = true;
  String _selectedSemester = '';
  String _selectedGrade = '';
  String _selectedDepartment = '';
  String _selectedSubject = '';
  String _selectedClass = '';

  @override
  void initState() {
    super.initState();
    _zhjwApi = getIt<ZhjwApiService>();
    getIt<ScuAuthProvider>().addListener(_onAuthChanged);
    _loadIndex();
  }

  @override
  void dispose() {
    getIt<ScuAuthProvider>().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = getIt<ScuAuthProvider>();
    if (auth.isLoggedIn && mounted) {
      _loadIndex();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadIndex() async {
    final auth = getIt<ScuAuthProvider>();
    if (!auth.isLoggedIn) return;
    setState(() => _isLoadingIndex = true);
    try {
      final result = await _zhjwApi.fetchClassScheduleInquiryIndex();
      if (!mounted) return;
      setState(() {
        _semesters = result.semesters;
        _grades = result.grades;
        _departments = result.departments;
        _isLoadingIndex = false;
      });
      await _search();
    } catch (e) {
      debugPrint('ClassScheduleInquiry index load error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'loadFailed';
        _isLoadingIndex = false;
      });
    }
  }

  Future<void> _loadSubjects(String departmentNum) async {
    if (departmentNum.isEmpty) {
      setState(() {
        _subjects = [];
        _selectedSubject = '';
      });
      return;
    }
    try {
      final subjects = await _zhjwApi.fetchSubjectsByDepartment(departmentNum);
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _selectedSubject = '';
      });
    } catch (e) {
      debugPrint('Load subjects error: $e');
    }
  }

  Future<void> _loadClassOptions() async {
    if (_selectedGrade.isEmpty || _selectedDepartment.isEmpty) {
      setState(() {
        _classOptions = [];
        _selectedClass = '';
      });
      return;
    }
    try {
      final options = await _zhjwApi.fetchClassOptions(
        yearNum: _selectedGrade,
        departmentNum: _selectedDepartment,
        subjectNum: _selectedSubject,
      );
      if (!mounted) return;
      setState(() {
        _classOptions = options;
        _selectedClass = '';
      });
    } catch (e) {
      debugPrint('Load class options error: $e');
    }
  }

  Future<void> _search() async {
    setState(() {
      _pageNum = 1;
      _classes = [];
      _hasMore = true;
      _error = null;
    });
    await _loadClasses();
  }

  Future<void> _refresh() async {
    await _search();
  }

  Future<void> _loadClasses() async {
    final auth = getIt<ScuAuthProvider>();
    if (!auth.isLoggedIn) return;

    if (_pageNum == 1) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await _zhjwApi.fetchClassList(
        pageNum: _pageNum,
        pageSize: _pageSize,
        executiveEducationPlanNum: _selectedSemester,
        yearNum: _selectedGrade,
        departmentNum: _selectedDepartment,
        subjectNum: _selectedSubject,
        classNum: _selectedClass,
      );
      if (!mounted) return;
      setState(() {
        _classes.addAll(result.classes);
        _hasMore = _classes.length < result.totalCount;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on UnauthenticatedException catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'sessionExpired';
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('ClassScheduleInquiry load error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'loadFailed';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;
    _pageNum++;
    _loadClasses();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.classScheduleInquiry)),
      body: ListenableBuilder(
        listenable: getIt<ScuAuthProvider>(),
        builder: (context, _) {
          final auth = getIt<ScuAuthProvider>();
          if (!auth.isLoggedIn) {
            if (auth.isAutoLoggingIn) return const AutoLoginLoadingWidget();
            return const LoginRequiredWidget();
          }
          return _buildContent(context);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoadingIndex) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error == 'sessionExpired'
                  ? l10n.sessionExpired
                  : l10n.loadFailed,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadIndex, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildFilterBar(context),
        Expanded(child: _buildClassList(context)),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.classScheduleInquiryFilter,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    value: _selectedSemester,
                    items: _semesters
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.value,
                            child: Text(
                              s.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSemester = v),
                    hint: l10n.classScheduleInquirySemester,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    value: _selectedGrade,
                    items: _grades
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text('$g级', overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => _selectedGrade = v);
                      _loadClassOptions();
                    },
                    hint: l10n.classScheduleInquiryGrade,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    value: _selectedDepartment,
                    items: _departments
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.value,
                            child: Text(
                              d.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedDepartment = v;
                        _selectedSubject = '';
                        _subjects = [];
                      });
                      _loadSubjects(v);
                      _loadClassOptions();
                    },
                    hint: l10n.classScheduleInquiryDepartment,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    value: _selectedSubject,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('全部')),
                      ..._subjects.map(
                        (s) => DropdownMenuItem(
                          value: s.code,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedSubject = v);
                      _loadClassOptions();
                    },
                    hint: l10n.classScheduleInquirySubject,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    value: _selectedClass,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('全部')),
                      ..._classOptions.map(
                        (c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedClass = v),
                    hint: l10n.classScheduleInquiryClass,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: Text(l10n.classScheduleInquirySearch),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String> onChanged,
    required String hint,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey('dropdown_$value'),
      initialValue: value.isEmpty && items.any((i) => i.value == '')
          ? ''
          : (value.isEmpty ? null : value),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        border: OutlineInputBorder(),
        isDense: true,
      ),
      isExpanded: true,
      hint: Text(hint, style: const TextStyle(fontSize: 13)),
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildClassList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_classes.isEmpty) {
      return Center(
        child: Text(
          l10n.classScheduleInquiryNoData,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _classes.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _classes.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _isLoadingMore
                    ? const CircularProgressIndicator()
                    : FilledButton.tonal(
                        onPressed: _loadMore,
                        child: Text(l10n.classScheduleInquiryLoadMore),
                      ),
              ),
            );
          }
          final classInfo = _classes[index];
          return _ClassCard(
            classInfo: classInfo,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ClassScheduleInquiryDetailPage(classInfo: classInfo),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final ClassInfo classInfo;
  final VoidCallback onTap;

  const _ClassCard({required this.classInfo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            classInfo.className.length >= 4
                ? classInfo.className.substring(classInfo.className.length - 4)
                : classInfo.className,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          classInfo.className,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              classInfo.subjectName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (classInfo.departmentName.isNotEmpty)
              Text(
                classInfo.departmentName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
