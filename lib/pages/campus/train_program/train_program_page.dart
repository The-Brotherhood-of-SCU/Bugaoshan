import 'package:flutter/material.dart';
import 'package:Bugaoshan/injection/injector.dart';
import 'package:Bugaoshan/l10n/app_localizations.dart';
import 'package:Bugaoshan/pages/campus/train_program/models/train_program.dart';
import 'package:Bugaoshan/pages/campus/train_program/train_program_provider.dart';
import 'package:Bugaoshan/providers/scu_auth_provider.dart';

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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.trainProgramLoginRequired,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _buildContent(context);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildFilters(context),
        Expanded(child: _buildProgramsList(context)),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
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
                        _provider.gradesState == TrainProgramLoadState.loaded
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
            ? Text(_provider.collegesError ?? l10n.loadFailed)
            : DropdownButtonFormField<String>(
                value: _provider.selectedCollege,
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
            ? Text(_provider.gradesError ?? l10n.loadFailed)
            : DropdownButtonFormField<String>(
                value: _provider.selectedGrade,
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
      TrainProgramLoadState.error => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _provider.programsError ?? l10n.trainProgramLoadFailed,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _provider.searchPrograms(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.gradesRetry),
            ),
          ],
        ),
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
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
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

class TrainProgramDetailPage extends StatefulWidget {
  final String fajhh;

  const TrainProgramDetailPage({super.key, required this.fajhh});

  @override
  State<TrainProgramDetailPage> createState() => _TrainProgramDetailPageState();
}

class _TrainProgramDetailPageState extends State<TrainProgramDetailPage> {
  late final TrainProgramProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = getIt<TrainProgramProvider>();
    _provider.fetchProgramDetail(widget.fajhh);
  }

  @override
  void dispose() {
    _provider.clearDetail();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trainProgramDetail)),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          return switch (_provider.detailState) {
            TrainProgramLoadState.idle || TrainProgramLoadState.loading =>
              const Center(child: CircularProgressIndicator()),
            TrainProgramLoadState.error => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 56,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _provider.detailError ?? l10n.trainProgramLoadFailed,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _provider.fetchProgramDetail(widget.fajhh),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.gradesRetry),
                  ),
                ],
              ),
            ),
            TrainProgramLoadState.loaded => _buildDetailContent(context),
          };
        },
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detail = _provider.currentDetail!;
    final info = detail.jhFajhb;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.famc,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    info.jhmc,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(context, l10n.trainProgramMajor, info.zym),
                  _buildInfoRow(context, '学院', info.xsm),
                  _buildInfoRow(context, '年级', info.njmc),
                  _buildInfoRow(context, '学制', info.xzlxmc),
                  _buildInfoRow(context, '学位类型', info.xdlxmc),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        context,
                        l10n.trainProgramCredits,
                        info.yqzxf.toStringAsFixed(0),
                      ),
                      _buildStatItem(
                        context,
                        l10n.trainProgramHours,
                        info.kczxs.toStringAsFixed(0),
                      ),
                      _buildStatItem(
                        context,
                        l10n.trainProgramCourses,
                        info.kczms.toString(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (info.pymb.isNotEmpty) ...[
            Text(
              l10n.trainProgramObjective,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  info.pymb,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            '课程结构',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTreeView(context),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTreeView(BuildContext context) {
    final detail = _provider.currentDetail!;
    final nodes = detail.treeList;

    final rootNodes = nodes
        .where((n) => n.pId == '-1' || n.pId == '-')
        .toList();
    final childMap = <String, List<TreeNode>>{};
    for (final node in nodes) {
      if (node.pId != '-1' && node.pId != '-') {
        childMap.putIfAbsent(node.pId, () => []).add(node);
      }
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rootNodes.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          return _buildTreeNode(context, rootNodes[index], childMap, 0);
        },
      ),
    );
  }

  Widget _buildTreeNode(
    BuildContext context,
    TreeNode node,
    Map<String, List<TreeNode>> childMap,
    int depth,
  ) {
    final children = childMap[node.id] ?? [];
    final hasChildren = children.isNotEmpty;
    final plainName = node.name.replaceAll(RegExp(r'<[^>]+>'), '').trim();

    if (hasChildren) {
      return ExpansionTile(
        leading: Icon(Icons.folder_outlined, size: 20),
        title: Text(plainName, style: Theme.of(context).textTheme.bodyMedium),
        children: children.map((child) {
          return _buildTreeNode(context, child, childMap, depth + 1);
        }).toList(),
      );
    } else {
      return ListTile(
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 16.0),
        leading: Icon(
          Icons.description_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(plainName, style: Theme.of(context).textTheme.bodyMedium),
        dense: true,
        onTap: () => _showCourseDetail(context, node.urlPath),
      );
    }
  }

  void _showCourseDetail(BuildContext context, String urlPath) {
    _provider.fetchCourseDetail(urlPath);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return ListenableBuilder(
            listenable: _provider,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: _buildCourseDetailContent(
                        context,
                        scrollController,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ).whenComplete(() => _provider.clearCourseDetail());
  }

  Widget _buildCourseDetailContent(
    BuildContext context,
    ScrollController scrollController,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return switch (_provider.courseDetailState) {
      TrainProgramLoadState.idle || TrainProgramLoadState.loading =>
        const Center(child: CircularProgressIndicator()),
      TrainProgramLoadState.error => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _provider.courseDetailError ?? l10n.trainProgramLoadFailed,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                // Retry is not easy here since we need the urlPath
                Navigator.pop(context);
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.gradesRetry),
            ),
          ],
        ),
      ),
      TrainProgramLoadState.loaded => _buildCourseDetailLoaded(
        context,
        scrollController,
      ),
    };
  }

  Widget _buildCourseDetailLoaded(
    BuildContext context,
    ScrollController scrollController,
  ) {
    final detail = _provider.currentCourseDetail!;
    final kc = detail.kc;
    final jhkc = detail.jhkc;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kc.kcm,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (kc.ywkcm.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              kc.ywkcm,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCourseInfoRow(context, '课程号', kc.kch),
                  _buildCourseInfoRow(context, '学分', kc.xf),
                  _buildCourseInfoRow(context, '学时', kc.xs),
                  _buildCourseInfoRow(context, '开课学院', kc.xsm),
                  _buildCourseInfoRow(context, '课程类别', kc.kclbmc),
                  _buildCourseInfoRow(context, '考核方式', kc.kslxmc),
                  _buildCourseInfoRow(context, '教学方式', kc.jxfssm),
                  _buildCourseInfoRow(
                    context,
                    '内含学时',
                    '${kc.knzxs}/${kc.jkzxs}/${kc.sjzxs}/${kc.syzxs}',
                  ),
                  _buildCourseInfoRow(context, '建议修读年级', kc.nrjj),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '课程安排',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCourseInfoRow(context, '方案名称', jhkc.famc),
                  _buildCourseInfoRow(context, '课程属性', jhkc.kcsxmc),
                  _buildCourseInfoRow(context, '学年', jhkc.xnmc),
                  _buildCourseInfoRow(context, '学期', jhkc.xqm),
                  _buildCourseInfoRow(context, '学分', jhkc.xf),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseInfoRow(BuildContext context, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
