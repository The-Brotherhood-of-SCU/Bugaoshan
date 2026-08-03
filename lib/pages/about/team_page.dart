import 'package:flutter/material.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/open_link.dart';
import 'package:bugaoshan/widgets/common/info_card.dart';
import 'package:bugaoshan/widgets/common/styled_tile.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.developmentTeam)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          _buildHeader(theme, primaryColor),
          const SizedBox(height: 24),
          _buildIntroSection(theme, onSurfaceVariant, l10n),
          const SizedBox(height: 24),
          _buildContributeSection(theme, onSurfaceVariant, l10n),
          const SizedBox(height: 24),
          InfoCard(
            children: [
              StackedTile(
                icon: Icons.group_outlined,
                label: "Github",
                value: 'The Brotherhood of SCU',
                onTap: () => openLink(orgLink),
                trailing: Icons.open_in_new,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color primaryColor) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
              child: Image.asset(
                'assets/brotherhood-of-scu.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'The Brotherhood of SCU',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroSection(
    ThemeData theme,
    Color onSurfaceVariant,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.teamIntroTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.teamIntroDesc,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: onSurfaceVariant,
            height: 1.7,
          ),
        ),
      ],
    );
  }

  Widget _buildContributeSection(
    ThemeData theme,
    Color onSurfaceVariant,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.teamJoinUsTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.teamContributeDesc,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.teamContributeClosing,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
