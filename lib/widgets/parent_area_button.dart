import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// The one labelled door from a child screen into the parent dashboard. An
/// icon on its own read as decoration, so the words travel with it everywhere
/// it appears.
class ParentAreaButton extends StatelessWidget {
  const ParentAreaButton({
    required this.onPressed,
    this.compact = false,
    super.key,
  });

  final VoidCallback onPressed;

  /// Trims the button down for a spot inside a header, where it sits beside
  /// other content rather than filling a bar of its own.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.honey,
        foregroundColor: AppColors.ink,
        minimumSize: compact ? const Size(0, 42) : const Size(48, 52),
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 14)
            : const EdgeInsets.symmetric(horizontal: 12),
        textStyle: TextStyle(
          fontSize: compact ? 13 : 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.family_restroom_rounded, size: 20),
      label: const Text(
        'Parent dashboard',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
