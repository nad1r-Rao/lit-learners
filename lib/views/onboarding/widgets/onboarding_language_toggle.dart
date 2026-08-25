import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/onboarding_strings.dart';
import '../../../models/onboarding.dart';
import '../../../viewmodels/onboarding_viewmodel.dart';

/// App bar control that swaps the onboarding flow between English and Urdu.
///
/// Each option is labelled in its own script so a parent who reads only one of
/// the two can still find it.
class OnboardingLanguageToggle extends StatelessWidget {
  const OnboardingLanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingViewModel>();
    final selected = onboarding.language;

    return Tooltip(
      message: OnboardingStrings.of(selected).changeLanguage,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.lavender,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.lilac.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in OnboardingLanguage.values)
              _ToggleChip(
                language: language,
                selected: language == selected,
                onTap: () => context
                    .read<OnboardingViewModel>()
                    .setLanguage(language),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
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
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.violet : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Directionality(
            textDirection: language.textDirection,
            child: Text(
              language.nativeLabel,
              style: language.styleFor(
                TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Colors.white
                      : AppColors.ink.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
