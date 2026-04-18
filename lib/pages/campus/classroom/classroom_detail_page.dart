import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/models/building_model.dart';
import 'package:bugaoshan/pages/campus/models/room_model.dart';

class ClassroomDetailPage extends StatelessWidget {
  final BuildingModel building;
  final RoomData room;

  const ClassroomDetailPage({
    super.key,
    required this.building,
    required this.room,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(room.roomName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(context, l10n),
            const SizedBox(height: 16),
            Text('时段状态', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildPeriodGrid(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, AppLocalizations l10n) {
    final freePeriods = room.classUses
        .where((c) => !c.isInUse && !c.isBorrowed)
        .length;
    final classPeriods = room.classUses.where((c) => c.isInUse).length;
    final borrowedPeriods = room.classUses.where((c) => c.isBorrowed).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room.roomName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '${building.name} · ${building.campusName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusBadge(
                  context,
                  '空闲',
                  '$freePeriods/${room.classUses.length}',
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(
                  context,
                  '上课',
                  '$classPeriods/${room.classUses.length}',
                  Colors.red,
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(
                  context,
                  '借用',
                  '$borrowedPeriods/${room.classUses.length}',
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '座位数: ${room.seatCount}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    String label,
    String count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
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
    final periodLabels = ['第1节', '第2节', '第3节', '第4节', '第5节'];

    return Column(
      children: [
        for (int i = 0; i < room.classUses.length; i++)
          _buildPeriodRow(context, l10n, i, periodLabels),
      ],
    );
  }

  Widget _buildPeriodRow(
    BuildContext context,
    AppLocalizations l10n,
    int index,
    List<String> periodLabels,
  ) {
    final classUse = room.classUses[index];
    final periodLabel = index < periodLabels.length
        ? periodLabels[index]
        : '第${index + 1}节';

    Color bgColor;
    IconData icon;
    String statusText;

    if (classUse.isInUse) {
      bgColor = Colors.red.withOpacity(0.12);
      icon = Icons.school;
      statusText = '上课中';
    } else if (classUse.isBorrowed) {
      bgColor = Colors.orange.withOpacity(0.12);
      icon = Icons.lock_outline;
      statusText = '已借用';
    } else {
      bgColor = Colors.green.withOpacity(0.12);
      icon = Icons.check_circle_outline;
      statusText = '空闲';
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
            Icon(icon, color: _getStatusColor(classUse), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(classUse),
                    ),
                  ),
                  if (classUse.isInUse && classUse.courseName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      classUse.courseName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (classUse.isInUse && classUse.teacherName.isNotEmpty) ...[
                    Text(
                      classUse.teacherName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ClassUseInfo classUse) {
    if (classUse.isInUse) return Colors.red;
    if (classUse.isBorrowed) return Colors.orange;
    return Colors.green;
  }
}
