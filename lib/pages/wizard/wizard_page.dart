import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:flutter/material.dart';
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
  late final AppConfigProvider _appConfig;
  int _currentPage = 0;
  static const int _totalPages = 3;

  @override
  void initState() {
    super.initState();
    _appConfig = getIt<AppConfigProvider>();
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
    _appConfig.acceptedEulaVersion.value = currentEulaVersion;
    _appConfig.firstLaunchWizardCompleted.value = true;
  }

  Future<void> _goNext() async {
    if (_currentPage == 0) {
      final canContinue = await ensureEulaAgreement(context);
      if (!mounted || !canContinue) return;
    }
    _pageController.nextPage(
      duration: _appConfig.cardSizeAnimationDuration.value,
      curve: Curves.easeInOutQuart,
    );
  }

  void _goBack() {
    _pageController.previousPage(
      duration: _appConfig.cardSizeAnimationDuration.value,
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
                duration: _appConfig.cardSizeAnimationDuration.value,
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
                duration: _appConfig.cardSizeAnimationDuration.value,
                child: TextButton(onPressed: _goBack, child: Text(l10n.back)),
              ),
              const SizedBox(width: 8),
              AnimatedSize(
                duration: _appConfig.cardSizeAnimationDuration.value,
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
