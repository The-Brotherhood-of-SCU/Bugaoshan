import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/class_schedule_inquiry/class_schedule_inquiry_detail_page.dart';
import 'package:bugaoshan/pages/campus/filter_input_decoration.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/campus/class_schedule_inquiry_pods.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/utils/system_insets.dart';

class ClassScheduleInquiryPage extends ConsumerStatefulWidget {
  const ClassScheduleInquiryPage({super.key});

  @override
  ConsumerState<ClassScheduleInquiryPage> createState() =>
      _ClassScheduleInquiryPageState();
}

class _ClassScheduleInquiryPageState
    extends ConsumerState<ClassScheduleInquiryPage> {
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
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = ref.read(scuAuthProviderBridge);
    if (auth.isLoggedIn) {
      ref.read(classScheduleInquiryProvider.notifier).ensureIndex();
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
          appBar: AppBar(title: Text(l10n.classScheduleInquiry)),
          body: const AutoLoginLoadingWidget(),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(l10n.classScheduleInquiry)),
        body: const LoginRequiredWidget(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.classScheduleInquiry)),
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final state = ref.watch(classScheduleInquiryProvider);

    if (state.indexState == ClassScheduleInquiryLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.indexError != null && state.classes.isEmpty) {
      return RetryableErrorWidget(
        errorType: state.indexError!,
        onRetry: () => ref
            .read(classScheduleInquiryProvider.notifier)
            .loadIndex(forceRefresh: true),
      );
    }

    return Column(
      children: [
        _buildFilterBar(context, state),
        Expanded(child: _buildClassList(context, state)),
      ],
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    ClassScheduleInquiryState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(classScheduleInquiryProvider.notifier);

    return CardWithTitle(
      title: l10n.classScheduleInquiryFilter,
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
                    hint: l10n.classScheduleInquirySemester,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    value: state.selectedGrade,
                    items: state.grades
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text(
                              l10n.gradeSuffix(g.toString()),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: notifier.setSelectedGrade,
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
                    value: state.selectedDepartment,
                    items: state.departments
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
                    onChanged: notifier.setSelectedDepartment,
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
                    value: state.selectedSubject,
                    items: [
                      DropdownMenuItem(value: '', child: Text(l10n.all)),
                      ...state.subjects.map(
                        (s) => DropdownMenuItem(
                          value: s.code,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: notifier.setSelectedSubject,
                    hint: l10n.classScheduleInquirySubject,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    value: state.selectedClass,
                    items: [
                      DropdownMenuItem(value: '', child: Text(l10n.all)),
                      ...state.classOptions.map(
                        (c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: notifier.setSelectedClass,
                    hint: l10n.classScheduleInquiryClass,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: notifier.search,
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

  Widget _buildClassList(
    BuildContext context,
    ClassScheduleInquiryState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(classScheduleInquiryProvider.notifier);

    if (state.classesState == ClassScheduleInquiryLoadState.loading &&
        state.classes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.classesError != null && state.classes.isEmpty) {
      return RetryableErrorWidget(
        errorType: state.classesError!,
        onRetry: notifier.search,
      );
    }

    if (state.classes.isEmpty) {
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
      onRefresh: notifier.refresh,
      child: ListView.builder(
        padding: withSystemBottomInset(context, const EdgeInsets.all(12)),
        itemCount: state.classes.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.classes.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: state.isLoadingMore
                    ? const CircularProgressIndicator()
                    : FilledButton.tonal(
                        // 列表非空时的 classesError 只可能来自
                        // 加载更多失败，此时按钮即重试入口。
                        onPressed: notifier.loadMore,
                        child: Text(
                          state.classesError != null
                              ? l10n.retry
                              : l10n.classScheduleInquiryLoadMore,
                        ),
                      ),
              ),
            );
          }
          final classInfo = state.classes[index];
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
    return StyledCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            classInfo.className.length >= 4
                ? classInfo.className.substring(classInfo.className.length - 4)
                : classInfo.className,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
