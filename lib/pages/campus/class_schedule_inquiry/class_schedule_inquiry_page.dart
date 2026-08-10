import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/class_schedule_inquiry/class_schedule_inquiry_detail_page.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/providers/class_schedule_inquiry_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';

class ClassScheduleInquiryPage extends StatefulWidget {
  const ClassScheduleInquiryPage({super.key});

  @override
  State<ClassScheduleInquiryPage> createState() =>
      _ClassScheduleInquiryPageState();
}

class _ClassScheduleInquiryPageState extends State<ClassScheduleInquiryPage> {
  late final ClassScheduleInquiryProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = getIt<ClassScheduleInquiryProvider>();
    getIt<ScuAuthProvider>().addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void dispose() {
    getIt<ScuAuthProvider>().removeListener(_onAuthChanged);
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
      appBar: AppBar(title: Text(l10n.classScheduleInquiry)),
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
    if (_provider.indexState == ClassScheduleInquiryLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_provider.indexError != null && _provider.classes.isEmpty) {
      return RetryableErrorWidget(
        errorType: _provider.indexError!,
        onRetry: () => _provider.loadIndex(forceRefresh: true),
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
                    hint: l10n.classScheduleInquirySemester,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    value: _provider.selectedGrade,
                    items: _provider.grades
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
                    onChanged: _provider.setSelectedGrade,
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
                    value: _provider.selectedDepartment,
                    items: _provider.departments
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
                    onChanged: _provider.setSelectedDepartment,
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
                    value: _provider.selectedSubject,
                    items: [
                      DropdownMenuItem(value: '', child: Text(l10n.all)),
                      ..._provider.subjects.map(
                        (s) => DropdownMenuItem(
                          value: s.code,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: _provider.setSelectedSubject,
                    hint: l10n.classScheduleInquirySubject,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
                    value: _provider.selectedClass,
                    items: [
                      DropdownMenuItem(value: '', child: Text(l10n.all)),
                      ..._provider.classOptions.map(
                        (c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: _provider.setSelectedClass,
                    hint: l10n.classScheduleInquiryClass,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _provider.search,
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
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        border: OutlineInputBorder(),
        isDense: false,
      ),
      isExpanded: true,
      hint: Text(hint, style: Theme.of(context).textTheme.bodyMedium),
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildClassList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_provider.classesState == ClassScheduleInquiryLoadState.loading &&
        _provider.classes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_provider.classesError != null && _provider.classes.isEmpty) {
      return RetryableErrorWidget(
        errorType: _provider.classesError!,
        onRetry: _provider.search,
      );
    }

    if (_provider.classes.isEmpty) {
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
      onRefresh: _provider.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _provider.classes.length + (_provider.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _provider.classes.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _provider.isLoadingMore
                    ? const CircularProgressIndicator()
                    : FilledButton.tonal(
                        onPressed: _provider.loadMore,
                        child: Text(l10n.classScheduleInquiryLoadMore),
                      ),
              ),
            );
          }
          final classInfo = _provider.classes[index];
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
