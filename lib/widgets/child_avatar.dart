import 'dart:io';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/avatar_presets.dart';

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
    final preset = AvatarPresets.byId(avatarValue);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? preset?.background ?? AppColors.lavender,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: _avatarImage() ??
          (preset == null
              ? _AvatarFallback(name: name, textColor: textColor)
              : _PresetFace(preset: preset, radius: radius)),
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

class _PresetFace extends StatelessWidget {
  const _PresetFace({required this.preset, required this.radius});

  final AvatarPreset preset;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        preset.emoji,
        textAlign: TextAlign.center,
        // The emoji glyph sits inside its own padding, so it needs more than
        // the radius to fill the circle the way an initial does.
        style: TextStyle(fontSize: radius * 1.15, height: 1.15),
      ),
    );
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
