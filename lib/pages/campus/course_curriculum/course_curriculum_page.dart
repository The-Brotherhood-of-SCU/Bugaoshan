import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/course_curriculum/course_curriculum_detail_page.dart';
import 'package:bugaoshan/pages/campus/models/course_curriculum_model.dart';
import 'package:bugaoshan/providers/course_curriculum_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';

class CourseCurriculumPage extends StatefulWidget {
  const CourseCurriculumPage({super.key});

  @override
  State<CourseCurriculumPage> createState() => _CourseCurriculumPageState();
}

class _CourseCurriculumPageState extends State<CourseCurriculumPage> {
  late final CourseCurriculumProvider _provider;
  final _courseNameController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _courseSeqController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _provider = getIt<CourseCurriculumProvider>();
    getIt<ScuAuthProvider>().addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onAuthChanged();
    });
  }

  @override
  void dispose() {
    getIt<ScuAuthProvider>().removeListener(_onAuthChanged);
    _courseNameController.dispose();
    _courseCodeController.dispose();
    _courseSeqController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = getIt<ScuAuthProvider>();
    if (auth.isLoggedIn) _provider.ensureIndex();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.courseCurriculum)),
      body: ListenableBuilder(
        listenable: Listenable.merge([_provider, getIt<ScuAuthProvider>()]),
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
    if (_provider.indexState == CourseCurriculumLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_provider.indexError != null && _provider.courses.isEmpty) {
      return RetryableErrorWidget(
        errorType: _provider.indexError!,
        onRetry: () => _provider.loadIndex(forceRefresh: true),
      );
    }

    return Column(
      children: [
        _buildFilterBar(context),
        Expanded(child: _buildCourseList(context)),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CardWithTitle(
      title: l10n.courseCurriculumFilter,
      icon: const Icon(Icons.tune),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    value: _provider.selectedSemester,
                    items: _provider.semesters
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
                    onChanged: _provider.setSelectedSemester,
                    hint: l10n.courseCurriculumSemester,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    value: _provider.selectedDepartment,
                    items: [
                      DropdownMenuItem(value: '', child: Text(l10n.all)),
                      ..._provider.departments.map(
                        (d) => DropdownMenuItem(
                          value: d.value,
                          child: Text(d.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: _provider.setSelectedDepartment,
                    hint: l10n.courseCurriculumDepartment,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    value: _provider.selectedCategory,
                    items: [
                      DropdownMenuItem(value: '', child: Text(l10n.all)),
                      ..._provider.categories.map(
                        (c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: _provider.setSelectedCategory,
                    hint: l10n.courseCurriculumCategory,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    controller: _courseNameController,
                    hint: l10n.courseCurriculumCourseName,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _courseCodeController,
                    hint: l10n.courseCurriculumCourseCode,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    controller: _courseSeqController,
                    hint: l10n.courseCurriculumCourseSeq,
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
                label: Text(l10n.courseCurriculumSearch),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _search() {
    FocusScope.of(context).unfocus();
    _provider.setCourseName(_courseNameController.text.trim());
    _provider.setCourseCode(_courseCodeController.text.trim());
    _provider.setCourseSeq(_courseSeqController.text.trim());
    _provider.search();
  }

  /// 查询条件里下拉框与文本框共用同一套装饰配置。
  /// 不加 isDense，让 InputDecorator 取 M3 标准交互高度
  /// （kMinInteractiveDimension = 48），与培养方案、成绩等页面的
  /// 筛选控件高度一致，避免比应用内其他输入框矮一截。
  static const InputDecoration _filterInputDecoration = InputDecoration(
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    border: OutlineInputBorder(),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: _filterInputDecoration.copyWith(
        hintText: hint,
        hintStyle: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String> onChanged,
    required String hint,
  }) {
    final hasEmptyOption = items.any((i) => i.value == '');
    final initialValue = value.isEmpty ? (hasEmptyOption ? '' : null) : value;
    return DropdownButtonFormField<String>(
      key: ValueKey('dropdown_$value'),
      initialValue: initialValue,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: _filterInputDecoration,
      isExpanded: true,
      hint: Text(hint, style: Theme.of(context).textTheme.bodyMedium),
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildCourseList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_provider.coursesState == CourseCurriculumLoadState.loading &&
        _provider.courses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_provider.coursesError != null && _provider.courses.isEmpty) {
      return RetryableErrorWidget(
        errorType: _provider.coursesError!,
        onRetry: _provider.search,
      );
    }

    if (_provider.courses.isEmpty) {
      return Center(
        child: Text(
          l10n.courseCurriculumNoData,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _provider.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _provider.courses.length + (_provider.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _provider.courses.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _provider.isLoadingMore
                    ? const CircularProgressIndicator()
                    : FilledButton.tonal(
                        onPressed: _provider.loadMore,
                        child: Text(l10n.courseCurriculumLoadMore),
                      ),
              ),
            );
          }
          final courseInfo = _provider.courses[index];
          return _CourseCard(
            courseInfo: courseInfo,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    CourseCurriculumDetailPage(courseInfo: courseInfo),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseSectionInfo courseInfo;
  final VoidCallback onTap;

  const _CourseCard({required this.courseInfo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            courseInfo.credits.isNotEmpty ? courseInfo.credits : '-',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          courseInfo.courseName,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${courseInfo.courseCode} · ${courseInfo.courseSeq}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (courseInfo.teachers.isNotEmpty)
              Text(
                courseInfo.teachers,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (courseInfo.category.isNotEmpty ||
                courseInfo.department.isNotEmpty)
              Text(
                [
                  if (courseInfo.category.isNotEmpty) courseInfo.category,
                  if (courseInfo.department.isNotEmpty) courseInfo.department,
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
