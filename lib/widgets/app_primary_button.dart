import 'package:flutter/material.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.labelStyle,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// Merged over the theme's button text style. Needed for scripts the display
  /// font has no glyphs for, such as Urdu.
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: labelStyle);
    final child = icon == null
        ? text
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Flexible(child: text),
            ],
          );

    return FilledButton(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: onPressed,
      child: child,
    );
  }
}
