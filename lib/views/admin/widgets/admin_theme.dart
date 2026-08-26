import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// The admin panel's share of the app's visual language.
///
/// These are deliberately the same shapes the parent dashboard uses — the
/// grape/violet header, panel cards outlined in lilac at an 18px radius, and
/// accent-washed tiles — so the portal reads as part of Little Learners rather
/// than as a bare Material admin console bolted onto it.
class AdminPalette {
  const AdminPalette._();

  /// Card and tile corner radius used across the app.
  static const radius = 18.0;

  /// The header gradient shared with the parent dashboard.
  static const headerGradient = LinearGradient(
    colors: [AppColors.grape, AppColors.violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// The hairline that outlines every soft card.
  static Border get cardBorder => Border.all(
        color: AppColors.lilac.withValues(alpha: 0.46),
      );
}

/// Panel card with the app's lilac hairline and 18px radius.
///
/// Replaces the plain Material [Card] the admin screens used to reach for,
/// which rendered a grey-bordered rectangle that matched nothing else.
class AdminSoftCard extends StatelessWidget {
  const AdminSoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: AdminPalette.cardBorder,
        borderRadius: BorderRadius.circular(AdminPalette.radius),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return decorated;

    // Material + InkWell rather than a bare GestureDetector so the tap ripple
    // stays inside the rounded corners.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminPalette.radius),
        child: decorated,
      ),
    );
  }
}

/// Heading plus an optional one-line explanation, sized like the section
/// titles on the parent dashboard.
class AdminSectionHeading extends StatelessWidget {
  const AdminSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.ink.withValues(alpha: 0.66),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Accent-washed count tile, matching the reward tiles on the parent
/// dashboard.
class AdminMetricTile extends StatelessWidget {
  const AdminMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.sky,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(AdminPalette.radius),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Translucent stat pill for use on top of the header gradient, where the
/// light-on-white metric tiles would disappear.
class AdminHeaderStat extends StatelessWidget {
  const AdminHeaderStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.honey),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Coral-washed failure notice, matching the inline errors elsewhere.
class AdminInlineError extends StatelessWidget {
  const AdminInlineError({
    super.key,
    required this.message,
    this.onDismiss,
  });

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, onDismiss == null ? 12 : 4, 12),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.coral),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (onDismiss != null)
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.coral,
            ),
        ],
      ),
    );
  }
}

/// Leaf-washed confirmation notice, the counterpart to [AdminInlineError].
class AdminInlineSuccess extends StatelessWidget {
  const AdminInlineSuccess({
    super.key,
    required this.message,
    this.onDismiss,
  });

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, onDismiss == null ? 12 : 4, 12),
      decoration: BoxDecoration(
        color: AppColors.leaf.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.leaf.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.leaf),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (onDismiss != null)
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.leaf,
            ),
        ],
      ),
    );
  }
}

/// "Nothing here yet" card, shaped like the empty states on the parent
/// dashboard rather than a bare centred sentence.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminSoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.violet, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.66),
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

/// Small labelled pill, used for counts and status alongside list rows.
class AdminPill extends StatelessWidget {
  const AdminPill({
    super.key,
    required this.label,
    this.icon,
    this.accent = AppColors.violet,
  });

  final String label;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Rounded progress bar on a lavender track, as used for stage progress on the
/// parent dashboard.
class AdminProgressBar extends StatelessWidget {
  const AdminProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.violet,
    this.minHeight = 6,
  });

  final double value;
  final Color color;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: minHeight,
        color: color,
        backgroundColor: AppColors.lavender,
      ),
    );
  }
}

/// Square icon chip that fronts a list row.
class AdminIconChip extends StatelessWidget {
  const AdminIconChip({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}
