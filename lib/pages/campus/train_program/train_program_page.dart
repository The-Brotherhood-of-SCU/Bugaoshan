import 'package:flutter/material.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program.dart';
import 'package:bugaoshan/providers/train_program_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/info_row.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';

part 'train_program_detail_page.dart';

class TrainProgramPage extends StatefulWidget {
  const TrainProgramPage({super.key});

  @override
  State<TrainProgramPage> createState() => _TrainProgramPageState();
}

class _TrainProgramPageState extends State<TrainProgramPage> {
  late final TrainProgramProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = getIt<TrainProgramProvider>();
    _provider.fetchCollegesAndGrades();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trainProgram)),
      body: ListenableBuilder(
        listenable: Listenable.merge([getIt<ScuAuthProvider>(), _provider]),
        builder: (context, _) {
          final auth = getIt<ScuAuthProvider>();
          if (!auth.isLoggedIn) {
            if (auth.isAutoLoggingIn) {
              return const AutoLoginLoadingWidget();
            }
            return const LoginRequiredWidget();
          }
          return _buildContent(context);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        _buildFilters(context),
        Expanded(child: _buildProgramsList(context)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
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
                Expanded(child: _buildCollegeDropdown(context, l10n)),
                const SizedBox(width: 16),
                Expanded(child: _buildGradeDropdown(context, l10n)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _provider.collegesState == TrainProgramLoadState.loaded &&
                        _provider.gradesState == TrainProgramLoadState.loaded &&
                        _provider.selectedCollege != null &&
                        _provider.selectedGrade != null
                    ? () => _provider.searchPrograms()
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

  Widget _buildCollegeDropdown(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.trainProgramCollege,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        _provider.collegesState == TrainProgramLoadState.loading
            ? const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              )
            : _provider.collegesState == TrainProgramLoadState.error
            ? Text(l10n.loadFailed)
            : DropdownButtonFormField<String>(
                initialValue: _provider.selectedCollege,
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
                  ..._provider.colleges.map(
                    (c) => DropdownMenuItem(
                      value: c.value,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) {
                  _provider.setSelectedCollege(value);
                },
              ),
      ],
    );
  }

  Widget _buildGradeDropdown(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.trainProgramGrade,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        _provider.gradesState == TrainProgramLoadState.loading
            ? const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              )
            : _provider.gradesState == TrainProgramLoadState.error
            ? Text(l10n.loadFailed)
            : DropdownButtonFormField<String>(
                initialValue: _provider.selectedGrade,
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
                  ..._provider.grades.map(
                    (g) =>
                        DropdownMenuItem(value: g.value, child: Text(g.label)),
                  ),
                ],
                onChanged: (value) {
                  _provider.setSelectedGrade(value);
                },
              ),
      ],
    );
  }

  Widget _buildProgramsList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return switch (_provider.programsState) {
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
        errorType: _provider.programsError!,
        onRetry: () => _provider.searchPrograms(),
        iconSize: 56,
      ),
      TrainProgramLoadState.loaded =>
        _provider.programs.isEmpty
            ? Center(
                child: Text(
                  l10n.trainProgramNoData,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _provider.programs.length,
                itemBuilder: (context, index) {
                  final program = _provider.programs[index];
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
