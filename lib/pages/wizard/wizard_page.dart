import 'dart:io';

import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/wizard/welcome_page.dart';
import 'package:bugaoshan/pages/wizard/login_page.dart';
import 'package:bugaoshan/pages/wizard/features_page.dart';
import 'package:bugaoshan/widgets/dialog/eula_dialog.dart';
import 'package:bugaoshan/widgets/eula_content.dart';

class WizardPage extends StatefulWidget {
  const WizardPage({super.key});

  @override
  State<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends State<WizardPage> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _eulaAgreed = false;
  static const int _totalPages = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
    final appConfig = getIt<AppConfigProvider>();
    appConfig.acceptedEulaVersion.value = currentEulaVersion;
    appConfig.firstLaunchWizardCompleted.value = true;
  }

  Future<void> _goNext() async {
    if (_currentPage == 0 && !_eulaAgreed) {
      final appConfig = getIt<AppConfigProvider>();
      if (appConfig.acceptedEulaVersion.value >= currentEulaVersion) {
        setState(() => _eulaAgreed = true);
      } else {
        final agreed = await showEulaDialog(context);
        if (!mounted) return;
        if (agreed) {
          setState(() => _eulaAgreed = true);
        } else {
          exit(0);
        }
      }
    }
    _pageController.nextPage(
      duration: appConfigProvider.cardSizeAnimationDuration.value,
      curve: Curves.easeInOutQuart,
    );
  }

  void _goBack() {
    _pageController.previousPage(
      duration: appConfigProvider.cardSizeAnimationDuration.value,
      curve: Curves.easeInOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

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
                        physics: const NeverScrollableScrollPhysics(),
                        controller: _pageController,
                        children: const [
                          WelcomePage(),
                          LoginPage(),
                          FeaturesPage(),
                        ],
                      ),
                    ),
                    _buildBottomSection(l10n, colorScheme),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  AppConfigProvider appConfigProvider = getIt<AppConfigProvider>();

  Widget _buildBottomSection(AppLocalizations l10n, ColorScheme colorScheme) {
    final isLastPage = _currentPage == _totalPages - 1;
    final isFirstPage = _currentPage == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalPages, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: appConfigProvider.cardSizeAnimationDuration.value,
                curve: appCurve,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 30),
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
                duration: appConfigProvider.cardSizeAnimationDuration.value,
                child: TextButton(onPressed: _goBack, child: Text(l10n.back)),
              ),
              const SizedBox(width: 8),
              AnimatedSize(
                duration: appConfigProvider.cardSizeAnimationDuration.value,
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
