import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/pages/wizard/welcome_page.dart';
import 'package:bugaoshan/pages/wizard/student_type_page.dart';
import 'package:bugaoshan/pages/wizard/login_page.dart';
import 'package:bugaoshan/pages/wizard/features_page.dart';
import 'package:bugaoshan/pages/wizard/widget_page.dart';

class WizardPage extends ConsumerStatefulWidget {
  const WizardPage({super.key});

  @override
  ConsumerState<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends ConsumerState<WizardPage> {
  late final PageController _pageController;
  int _currentPage = 0;
  late final int _totalPages;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _pages = [
      const WelcomePage(),
      const StudentTypePage(),
      const LoginPage(),
      const FeaturesPage(),
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)
        const WidgetPage(),
    ];
    _totalPages = _pages.length;

    _pageController.addListener(() {
      final page = _pageController.page;
      if (page != null) {
        setState(() => _currentPage = page.round());
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onCompleted() {
    ref.read(firstLaunchWizardCompletedSettingProvider.notifier).update(true);
  }

  void _goNext() {
    final animDuration = ref.read(cardSizeAnimationDurationSettingProvider);
    _pageController.nextPage(
      duration: animDuration,
      curve: Curves.easeInOutQuart,
    );
  }

  void _goBack() {
    final animDuration = ref.read(cardSizeAnimationDurationSettingProvider);
    _pageController.previousPage(
      duration: animDuration,
      curve: Curves.easeInOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final animDuration = ref.watch(cardSizeAnimationDurationSettingProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SizedBox(
                width: constraints.maxWidth > 600 ? 600 : null,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        children: _pages,
                      ),
                    ),
                    _buildBottomSection(l10n, colorScheme, animDuration),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomSection(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    Duration animDuration,
  ) {
    final isLastPage = _currentPage == _totalPages - 1;
    final isFirstPage = _currentPage == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalPages, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: animDuration,
                curve: appCurve,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(AppShapes.xs),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!isFirstPage)
                TextButton(
                  onPressed: _onCompleted,
                  child: Text(l10n.onboardingSkip),
                ),
              const Spacer(),
              AnimatedOpacity(
                opacity: !isFirstPage ? 1 : 0,
                curve: appCurve,
                duration: animDuration,
                child: TextButton(onPressed: _goBack, child: Text(l10n.back)),
              ),
              const SizedBox(width: 8),
              AnimatedSize(
                duration: animDuration,
                curve: appCurve,
                child: FilledButton(
                  onPressed: isLastPage ? _onCompleted : _goNext,
                  child: Text(
                    isLastPage ? l10n.onboardingStart : l10n.onboardingNext,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
