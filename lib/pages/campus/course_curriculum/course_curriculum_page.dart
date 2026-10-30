import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/course_curriculum/course_curriculum_detail_page.dart';
import 'package:bugaoshan/pages/campus/filter_input_decoration.dart';
import 'package:bugaoshan/pages/campus/models/course_curriculum_model.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/campus/course_curriculum_pods.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/utils/system_insets.dart';

class CourseCurriculumPage extends ConsumerStatefulWidget {
  const CourseCurriculumPage({super.key});

  @override
  ConsumerState<CourseCurriculumPage> createState() =>
      _CourseCurriculumPageState();
}

class _CourseCurriculumPageState extends ConsumerState<CourseCurriculumPage> {
  final _courseNameController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _courseSeqController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(scuAuthProviderBridge).addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onAuthChanged();
    });
  }

  @override
  void dispose() {
    ref.read(scuAuthProviderBridge).removeListener(_onAuthChanged);
    _courseNameController.dispose();
    _courseCodeController.dispose();
    _courseSeqController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = ref.read(scuAuthProviderBridge);
    if (auth.isLoggedIn) {
      ref.read(courseCurriculumProvider.notifier).ensureIndex();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(scuAuthProviderBridge);

    if (!auth.isLoggedIn) {
      if (auth.isAutoLoggingIn) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.courseCurriculum)),
          body: const AutoLoginLoadingWidget(),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(l10n.courseCurriculum)),
        body: const LoginRequiredWidget(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.courseCurriculum)),
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final state = ref.watch(courseCurriculumProvider);

    if (state.indexState == CourseCurriculumLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.indexError != null && state.courses.isEmpty) {
      return RetryableErrorWidget(
        errorType: state.indexError!,
        onRetry: () => ref
            .read(courseCurriculumProvider.notifier)
            .loadIndex(forceRefresh: true),
      );
    }

    return Column(
      children: [
        _buildFilterBar(context, state),
        Expanded(child: _buildCourseList(context, state)),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context, CourseCurriculumState state) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(courseCurriculumProvider.notifier);

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
                    value: state.selectedSemester,
                    items: state.semesters
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
                    onChanged: notifier.setSelectedSemester,
                    hint: l10n.courseCurriculumSemester,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    value: state.selectedDepartment,
                    items: [
                      DropdownMenuItem(value: '', child: Text(l10n.all)),
                      ...state.departments.map(
                        (d) => DropdownMenuItem(
                          value: d.value,
                          child: Text(d.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: notifier.setSelectedDepartment,
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
                    value: state.selectedCategory,
                    items: [
                      DropdownMenuItem(value: '', child: Text(l10n.all)),
                      ...state.categories.map(
                        (c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: notifier.setSelectedCategory,
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
    final notifier = ref.read(courseCurriculumProvider.notifier);
    notifier.setCourseName(_courseNameController.text.trim());
    notifier.setCourseCode(_courseCodeController.text.trim());
    notifier.setCourseSeq(_courseSeqController.text.trim());
    notifier.search();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: kFilterInputDecoration.copyWith(
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
      decoration: kFilterInputDecoration,
      isExpanded: true,
      hint: Text(hint, style: Theme.of(context).textTheme.bodyMedium),
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildCourseList(BuildContext context, CourseCurriculumState state) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(courseCurriculumProvider.notifier);

    if (state.coursesState == CourseCurriculumLoadState.loading &&
        state.courses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.coursesError != null && state.courses.isEmpty) {
      return RetryableErrorWidget(
        errorType: state.coursesError!,
        onRetry: notifier.search,
      );
    }

    if (state.courses.isEmpty) {
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
      onRefresh: notifier.refresh,
      child: ListView.builder(
        padding: withSystemBottomInset(context, const EdgeInsets.all(12)),
        itemCount: state.courses.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.courses.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: state.isLoadingMore
                    ? const CircularProgressIndicator()
                    : FilledButton.tonal(
                        // 列表非空时的 coursesError 只可能来自
                        // 加载更多失败，此时按钮即重试入口。
                        onPressed: notifier.loadMore,
                        child: Text(
                          state.coursesError != null
                              ? l10n.retry
                              : l10n.courseCurriculumLoadMore,
                        ),
                      ),
              ),
            );
          }
          final courseInfo = state.courses[index];
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
