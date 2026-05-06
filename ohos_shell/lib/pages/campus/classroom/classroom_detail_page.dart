import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/models/classroom_model.dart';

class ClassroomDetailPage extends StatelessWidget {
  final ClassroomCampus campus;
  final ClassroomBuilding building;
  final ClassroomInfo room;
  final List<ClassroomTimeSlot> timeSlots;
  final String queryDate;
  final int teachingWeek;

  const ClassroomDetailPage({
    super.key,
    required this.campus,
    required this.building,
    required this.room,
    required this.timeSlots,
    required this.queryDate,
    required this.teachingWeek,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(room.classroomName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(context, l10n),
            const SizedBox(height: 16),
            Text(
              l10n.period,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildPeriodGrid(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, AppLocalizations l10n) {
    final statusMap = <int, ClassroomPeriodStatus>{};
    for (final slot in timeSlots) {
      statusMap[slot.sessionstart] = slot.status;
    }

    var freeCount = 0;
    var inClassCount = 0;
    var examCount = 0;
    var experimentCount = 0;
    var borrowedCount = 0;

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final isToday = queryDate == todayStr;

    for (int i = 1; i <= 12; i++) {
      final status = statusMap[i] ?? ClassroomPeriodStatus.free;
      switch (status) {
        case ClassroomPeriodStatus.free:
          freeCount++;
          break;
        case ClassroomPeriodStatus.inClass:
          inClassCount++;
          break;
        case ClassroomPeriodStatus.exam:
          examCount++;
          break;
        case ClassroomPeriodStatus.experiment:
          experimentCount++;
          break;
        case ClassroomPeriodStatus.borrowed:
          borrowedCount++;
          break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room.classroomName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${building.teachingBuildingName} · ${campus.campusName}校区',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusBadge(context, l10n.free, freeCount, Colors.green),
                _buildStatusBadge(
                  context,
                  l10n.inClass,
                  inClassCount,
                  Colors.red,
                ),
                _buildStatusBadge(
                  context,
                  l10n.classroomPeriodExam,
                  examCount,
                  Colors.orange,
                ),
                _buildStatusBadge(
                  context,
                  l10n.classroomPeriodExperiment,
                  experimentCount,
                  Colors.purple,
                ),
                _buildStatusBadge(
                  context,
                  l10n.borrowed,
                  borrowedCount,
                  Colors.amber,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.seats == "座" ? "座位数" : "Seats"}: ${room.placeNum}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (room.remark.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${l10n.classroomRemark}: ${room.remark}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (room.sfkjy == '是') ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.classroomCanBorrow,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
            if (teachingWeek > 0 && isToday) ...[
              const SizedBox(height: 4),
              Text(
                l10n.classroomTeachingWeek(teachingWeek),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (queryDate.isNotEmpty) ...[
              Text(
                l10n.classroomQueryDate(queryDate),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodGrid(BuildContext context, AppLocalizations l10n) {
    final statusMap = <int, ClassroomPeriodStatus>{};
    for (final slot in timeSlots) {
      statusMap[slot.sessionstart] = slot.status;
    }

    return Column(
      children: List.generate(12, (i) {
        final period = i + 1;
        final status = statusMap[period] ?? ClassroomPeriodStatus.free;
        return _buildPeriodRow(context, l10n, period, status);
      }),
    );
  }

  Widget _buildPeriodRow(
    BuildContext context,
    AppLocalizations l10n,
    int period,
    ClassroomPeriodStatus status,
  ) {
    final periodLabel = l10n.seats == "座" ? '第$period节' : 'P$period';

    Color bgColor;
    IconData icon;
    String statusText;

    switch (status) {
      case ClassroomPeriodStatus.free:
        bgColor = Colors.green.withValues(alpha: 0.12);
        icon = Icons.check_circle_outline;
        statusText = l10n.free;
        break;
      case ClassroomPeriodStatus.inClass:
        bgColor = Colors.red.withValues(alpha: 0.12);
        icon = Icons.school;
        statusText = l10n.inClass;
        break;
      case ClassroomPeriodStatus.exam:
        bgColor = Colors.orange.withValues(alpha: 0.12);
        icon = Icons.assignment;
        statusText = l10n.classroomPeriodExam;
        break;
      case ClassroomPeriodStatus.experiment:
        bgColor = Colors.purple.withValues(alpha: 0.12);
        icon = Icons.science;
        statusText = l10n.classroomPeriodExperiment;
        break;
      case ClassroomPeriodStatus.borrowed:
        bgColor = Colors.amber.withValues(alpha: 0.12);
        icon = Icons.lock_outline;
        statusText = l10n.borrowed;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                periodLabel,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, color: _getStatusColor(status), size: 20),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: _getStatusColor(status),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ClassroomPeriodStatus status) {
    switch (status) {
      case ClassroomPeriodStatus.free:
        return Colors.green;
      case ClassroomPeriodStatus.inClass:
        return Colors.red;
      case ClassroomPeriodStatus.exam:
        return Colors.orange;
      case ClassroomPeriodStatus.experiment:
        return Colors.purple;
      case ClassroomPeriodStatus.borrowed:
        return Colors.amber;
    }
  }
}
