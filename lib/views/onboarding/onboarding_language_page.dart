import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/onboarding_strings.dart';
import '../../core/routing/route_names.dart';
import '../../models/onboarding.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../widgets/app_primary_button.dart';

/// Sits between the parent guide and the readiness test so the parent picks
/// the language the test is written in before answering anything.
class OnboardingLanguagePage extends StatelessWidget {
  const OnboardingLanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingViewModel>();
    final language = onboarding.language;
    final strings = OnboardingStrings.of(language);

    return Scaffold(
      appBar: AppBar(
        title: Directionality(
          textDirection: language.textDirection,
          child: Text(
            strings.languageTitle,
            style: language.styleFor(null),
          ),
        ),
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: language.textDirection,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.grape, AppColors.violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.honey,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      strings.languageHeading,
                      textAlign: language.textAlign,
                      style: language.styleFor(
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      strings.languageSubtitle,
                      textAlign: language.textAlign,
                      style: language.styleFor(
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                              height: language.bodyLineHeight,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              for (final option in OnboardingLanguage.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LanguageOptionCard(
                    language: option,
                    selected: option == language,
                    onTap: () =>
                        context.read<OnboardingViewModel>().setLanguage(option),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                strings.languageNote,
                textAlign: language.textAlign,
                style: language.styleFor(
                  Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 18),
              AppPrimaryButton(
                icon: Icons.arrow_forward,
                label: strings.continueLabel,
                labelStyle: language.styleFor(null),
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(
                    RouteNames.onboardingTest,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOptionCard extends StatelessWidget {
  const _LanguageOptionCard({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final OnboardingLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: language.englishLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppColors.lavender : AppColors.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.violet : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Always shown in its own script so a parent who reads only
                    // one of the two can still recognise their language.
                    Directionality(
                      textDirection: language.textDirection,
                      child: Text(
                        language.nativeLabel,
                        style: language.styleFor(
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      language.englishLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink.withValues(alpha: 0.64),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.violet : AppColors.line,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
