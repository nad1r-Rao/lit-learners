import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// The strip along the bottom of every child screen that holds the grown-up
/// actions. Same place, same look on each screen, so "leave this child's
/// dashboard" is always found in one spot rather than hunted for in a header.
class ChildActionBar extends StatelessWidget {
  const ChildActionBar({required this.actions, super.key});

  /// Laid out as equal halves, so two actions never crowd each other on a
  /// small phone.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              for (final action in actions) ...[
                if (action != actions.first) const SizedBox(width: 10),
                Expanded(child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
