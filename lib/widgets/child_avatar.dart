import 'dart:io';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class ChildAvatar extends StatelessWidget {
  const ChildAvatar({
    required this.name,
    required this.avatarValue,
    this.radius = 24,
    this.backgroundColor,
    this.textColor = AppColors.ink,
    this.borderColor,
    super.key,
  });

  final String name;
  final String avatarValue;
  final double radius;
  final Color? backgroundColor;
  final Color textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final image = _avatarImage();
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? _presetColor(avatarValue),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: image ??
          Center(
            child: Text(
              _initials(name),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
    );
  }

  Widget? _avatarImage() {
    if (avatarValue.startsWith('http://') ||
        avatarValue.startsWith('https://')) {
      return Image.network(
        avatarValue,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _AvatarFallback(
          name: name,
          textColor: textColor,
        ),
      );
    }

    if (avatarValue.startsWith('file://') || avatarValue.startsWith('/')) {
      final path = avatarValue.startsWith('file://')
          ? Uri.parse(avatarValue).toFilePath()
          : avatarValue;
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _AvatarFallback(
          name: name,
          textColor: textColor,
        ),
      );
    }

    return null;
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.name,
    required this.textColor,
  });

  final String name;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _initials(name),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'LL';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

Color _presetColor(String value) {
  return switch (value) {
    'koala-coral' => AppColors.coral.withValues(alpha: 0.2),
    'koala-honey' => AppColors.honey.withValues(alpha: 0.32),
    'koala-green' => AppColors.sky.withValues(alpha: 0.18),
    _ => AppColors.lavender,
  };
}
