import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program.dart';
import 'package:bugaoshan/providers/riverpod/academic/train_program_pods.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/train_program_provider.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/info_row.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/utils/system_insets.dart';

part 'train_program_detail_page.dart';

class TrainProgramPage extends ConsumerStatefulWidget {
  const TrainProgramPage({super.key});

  @override
  ConsumerState<TrainProgramPage> createState() => _TrainProgramPageState();
}

class _TrainProgramPageState extends ConsumerState<TrainProgramPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(trainProgramProvider).fetchCollegesAndGrades();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(scuAuthProviderBridge);
    final provider = ref.watch(trainProgramProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trainProgram)),
      body: !auth.isLoggedIn
          ? auth.isAutoLoggingIn
              ? const AutoLoginLoadingWidget()
              : const LoginRequiredWidget()
          : _buildContent(context, provider),
    );
  }

  Widget _buildContent(BuildContext context, TrainProgramProvider provider) {
    return Column(
      children: [
        _buildFilters(context, provider),
        Expanded(child: _buildProgramsList(context, provider)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFilters(BuildContext context, TrainProgramProvider provider) {
    final l10n = AppLocalizations.of(context)!;

    return StyledCard(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildCollegeDropdown(context, l10n, provider)),
                const SizedBox(width: 16),
                Expanded(child: _buildGradeDropdown(context, l10n, provider)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    provider.collegesState == TrainProgramLoadState.loaded &&
                        provider.gradesState == TrainProgramLoadState.loaded &&
                        provider.selectedCollege != null &&
                        provider.selectedGrade != null
                    ? () => provider.searchPrograms()
                    : null,
                icon: const Icon(Icons.search),
                label: Text(l10n.trainProgramSearch),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollegeDropdown(
    BuildContext context,
    AppLocalizations l10n,
    TrainProgramProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.trainProgramCollege,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        provider.collegesState == TrainProgramLoadState.loading
            ? const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              )
            : provider.collegesState == TrainProgramLoadState.error
            ? Text(l10n.loadFailed)
            : DropdownButtonFormField<String>(
                initialValue: provider.selectedCollege,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: const OutlineInputBorder(),
                ),
                isExpanded: true,
                hint: Text(l10n.trainProgramAll),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(l10n.trainProgramAll),
                  ),
                  ...provider.colleges.map(
                    (c) => DropdownMenuItem(
                      value: c.value,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) {
                  provider.setSelectedCollege(value);
                },
              ),
      ],
    );
  }

  Widget _buildGradeDropdown(
    BuildContext context,
    AppLocalizations l10n,
    TrainProgramProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.trainProgramGrade,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        provider.gradesState == TrainProgramLoadState.loading
            ? const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              )
            : provider.gradesState == TrainProgramLoadState.error
            ? Text(l10n.loadFailed)
            : DropdownButtonFormField<String>(
                initialValue: provider.selectedGrade,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: const OutlineInputBorder(),
                ),
                isExpanded: true,
                hint: Text(l10n.trainProgramAll),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(l10n.trainProgramAll),
                  ),
                  ...provider.grades.map(
                    (g) =>
                        DropdownMenuItem(value: g.value, child: Text(g.label)),
                  ),
                ],
                onChanged: (value) {
                  provider.setSelectedGrade(value);
                },
              ),
      ],
    );
  }

  Widget _buildProgramsList(
    BuildContext context,
    TrainProgramProvider provider,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return switch (provider.programsState) {
      TrainProgramLoadState.idle => Center(
        child: Text(
          l10n.trainProgramNoData,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      TrainProgramLoadState.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      TrainProgramLoadState.error => RetryableErrorWidget(
        errorType: provider.programsError!,
        onRetry: () => provider.searchPrograms(),
        iconSize: 56,
      ),
      TrainProgramLoadState.loaded =>
        provider.programs.isEmpty
            ? Center(
                child: Text(
                  l10n.trainProgramNoData,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView.builder(
                padding: withSystemBottomInset(
                  context,
                  EdgeInsets.symmetric(horizontal: 16),
                ),
                itemCount: provider.programs.length,
                itemBuilder: (context, index) {
                  final program = provider.programs[index];
                  return StyledCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppShapes.small),
                        ),
                        child: Icon(
                          Icons.school_outlined,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        program.famc,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        program.jhmc,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showProgramDetail(context, program.fajhh),
                    ),
                  );
                },
              ),
    };
  }

  void _showProgramDetail(BuildContext context, String fajhh) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrainProgramDetailPage(fajhh: fajhh)),
    );
  }
}
