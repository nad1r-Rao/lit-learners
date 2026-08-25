import 'package:flutter/material.dart';

import 'app_colors.dart';

/// One of the ready-made avatars a parent can pick instead of a photo.
///
/// The [id] is what lands in `ChildProfile.avatarAsset`, so the four ids that
/// shipped before this catalog existed are kept verbatim — profiles already
/// saved on a device keep the face they were created with.
class AvatarPreset {
  const AvatarPreset({
    required this.id,
    required this.label,
    required this.emoji,
    required this.background,
  });

  final String id;
  final String label;

  /// Drawn instead of the child's initials. An emoji rather than an image
  /// asset: it stays sharp at every avatar size and adds nothing to the bundle.
  final String emoji;
  final Color background;
}

class AvatarPresets {
  const AvatarPresets._();

  static const all = <AvatarPreset>[
    AvatarPreset(
      id: 'koala-blue',
      label: 'Koala',
      emoji: '🐨',
      background: AppColors.lavender,
    ),
    AvatarPreset(
      id: 'koala-green',
      label: 'Frog',
      emoji: '🐸',
      background: Color(0xFFDDF7E8),
    ),
    AvatarPreset(
      id: 'koala-coral',
      label: 'Fox',
      emoji: '🦊',
      background: Color(0xFFFFE1DD),
    ),
    AvatarPreset(
      id: 'koala-honey',
      label: 'Lion',
      emoji: '🦁',
      background: Color(0xFFFFEFC4),
    ),
    AvatarPreset(
      id: 'koala-panda',
      label: 'Panda',
      emoji: '🐼',
      background: Color(0xFFEFF2F7),
    ),
    AvatarPreset(
      id: 'koala-bunny',
      label: 'Bunny',
      emoji: '🐰',
      background: Color(0xFFFFE4EF),
    ),
  ];

  static AvatarPreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  static AvatarPreset get fallback => all.first;
}
