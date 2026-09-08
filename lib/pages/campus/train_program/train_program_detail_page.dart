// 本文件是 `train_program_page.dart` 的 part：培养方案详情页。
//
// 包含 TrainProgramDetailPage（方案概览 + 课程架构树 + 课程详情 bottom sheet）。
// 与列表页共享主 library 的 import（material / models / provider / widgets）。
part of 'train_program_page.dart';

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
            TrainProgramLoadState.error => RetryableErrorWidget(
              errorType: _provider.detailError!,
              onRetry: () => _provider.fetchProgramDetail(widget.fajhh),
              iconSize: 56,
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
          StyledCard(
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
                  _buildInfoRow(context, l10n.trainProgramCollege, info.xsm),
                  _buildInfoRow(context, l10n.trainProgramGrade, info.njmc),
                  _buildInfoRow(
                    context,
                    l10n.trainProgramEducationSystem,
                    info.xzlxmc,
                  ),
                  _buildInfoRow(
                    context,
                    l10n.trainProgramDegreeType,
                    info.xdlxmc,
                  ),
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
            StyledCard(
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
            l10n.trainProgramCourseStructure,
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
    return InfoRow(label: label, value: value);
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

    return StyledCard(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rootNodes.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
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
        onTap: () => _showCourseDetail(context, node.urlPath, plainName),
      );
    }
  }

  void _showCourseDetail(
    BuildContext context,
    String urlPath,
    String? fallbackName,
  ) {
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
                    top: Radius.circular(AppShapes.large),
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
                        borderRadius: BorderRadius.circular(AppShapes.small),
                      ),
                    ),
                    Expanded(
                      child: _buildCourseDetailContent(
                        context,
                        scrollController,
                        fallbackName,
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
    String? fallbackName,
  ) {
    return switch (_provider.courseDetailState) {
      TrainProgramLoadState.idle || TrainProgramLoadState.loading =>
        const Center(child: CircularProgressIndicator()),
      TrainProgramLoadState.error => RetryableErrorWidget(
        errorType: _provider.courseDetailError!,
        onRetry: () => Navigator.pop(context),
      ),
      TrainProgramLoadState.loaded => _buildCourseDetailLoaded(
        context,
        scrollController,
        fallbackName,
      ),
    };
  }

  Widget _buildCourseDetailLoaded(
    BuildContext context,
    ScrollController scrollController,
    String? fallbackName,
  ) {
    final l10n = AppLocalizations.of(context)!;
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
                  kc.kcm == '' ? fallbackName ?? '' : kc.kcm,
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
          if (!detail.isOpenCourse)
            StyledCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildCourseInfoRow(
                      context,
                      l10n.trainProgramCourseNumber,
                      kc.kch,
                    ),
                    _buildCourseInfoRow(
                      context,
                      l10n.trainProgramCredits,
                      kc.xf,
                    ),
                    _buildCourseInfoRow(context, l10n.trainProgramHours, kc.xs),
                    _buildCourseInfoRow(
                      context,
                      l10n.trainProgramOpenCollege,
                      kc.xsm,
                    ),
                    _buildCourseInfoRow(
                      context,
                      l10n.trainProgramCourseType,
                      kc.kclbmc,
                    ),
                    _buildCourseInfoRow(
                      context,
                      l10n.trainProgramExamType,
                      kc.kslxmc,
                    ),
                    _buildCourseInfoRow(
                      context,
                      l10n.trainProgramTeachingMethod,
                      kc.jxfssm,
                    ),
                    _buildCourseHoursRow(context),
                    _buildCourseInfoRow(
                      context,
                      l10n.trainProgramObjective,
                      kc.nrjj,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (detail.isOpenCourse) ...[
            StyledCard(
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_open,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.trainProgramOpenCourse,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (jhkc != null) ...[
            Text(
              l10n.trainProgramCourseArrangement,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StyledCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildCourseInfoRow(
                      context,
                      l10n.trainProgramPlanName,
                      jhkc.famc,
                    ),
                    _buildCourseInfoRow(
                      context,
                      l10n.trainProgramCourseAttribute,
                      jhkc.kcsxmc,
                    ),
                    _buildCourseInfoRow(
                      context,
                      l10n.trainProgramAcademicYear,
                      jhkc.xnmc,
                    ),
                    _buildCourseInfoRow(
                      context,
                      l10n.trainProgramSemester,
                      jhkc.xqm,
                    ),
                    _buildCourseInfoRow(
                      context,
                      l10n.trainProgramCredits,
                      jhkc.xf,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseInfoRow(BuildContext context, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return InfoRow(label: label, value: value, labelWidth: 100);
  }

  Widget _buildCourseHoursRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final kc = _provider.currentCourseDetail!.kc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              l10n.trainProgramCourseHoursDetail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildHoursChip(context, l10n.trainProgramWeekHours, kc.knzxs),
                _buildHoursChip(context, l10n.trainProgramHours, kc.jkzxs),
                if (kc.sjzxs.isNotEmpty && kc.sjzxs != '0')
                  _buildHoursChip(
                    context,
                    l10n.trainProgramActualHours,
                    kc.sjzxs,
                  ),
                if (kc.syzxs.isNotEmpty && kc.syzxs != '0')
                  _buildHoursChip(
                    context,
                    l10n.trainProgramExperimentHours,
                    kc.syzxs,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursChip(BuildContext context, String label, String value) {
    if (value.isEmpty || value == '0') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppShapes.xs),
      ),
      child: Text(
        '$label:$value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
