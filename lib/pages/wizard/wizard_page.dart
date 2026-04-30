import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/pages/wizard/welcome_page.dart';
import 'package:bugaoshan/pages/wizard/login_page.dart';
import 'package:bugaoshan/pages/wizard/features_page.dart';

class WizardPage extends StatefulWidget {
  const WizardPage({super.key});

  @override
  State<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends State<WizardPage> {
  late final PageController _pageController;
  int _currentPage = 0;

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
    getIt<AppConfigProvider>().firstLaunchWizardCompleted.value = true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSkipButton(l10n),
            Expanded(
              child: PageView(
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
  }

  Widget _buildSkipButton(AppLocalizations l10n) {
    return Align(
      alignment: Alignment.topRight,
      child: TextButton(
        onPressed: _onCompleted,
        child: Text(l10n.onboardingSkip),
      ),
    );
  }

  Widget _buildBottomSection(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 32, right: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_currentPage < 2) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  _onCompleted();
                }
              },
              child: Text(
                _currentPage < 2
                    ? l10n.onboardingNext
                    : l10n.onboardingStart,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
