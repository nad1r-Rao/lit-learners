import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/learning_text_direction.dart';
import '../../../services/audio/koala_audio_player.dart';

/// Plays the audio cue attached to a content card, if the level ships one.
class ContentAudioButton extends StatefulWidget {
  const ContentAudioButton({required this.audioCueKey, super.key});

  static const learningAssetBasePath = 'audio/learning';

  final String? audioCueKey;

  @override
  State<ContentAudioButton> createState() => _ContentAudioButtonState();
}

class _ContentAudioButtonState extends State<ContentAudioButton> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final cueKey = widget.audioCueKey?.trim();
    final player = _maybeAudioPlayer(context);
    if (cueKey == null || cueKey.isEmpty || player == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: 'Play card audio',
      onPressed: _isPlaying ? null : () => _playCue(player, cueKey),
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(
        _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
      ),
    );
  }

  Future<void> _playCue(KoalaAudioPlayer player, String cueKey) async {
    setState(() => _isPlaying = true);
    try {
      await player.playCue(
        cueKey,
        assetBasePath: ContentAudioButton.learningAssetBasePath,
      );
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  KoalaAudioPlayer? _maybeAudioPlayer(BuildContext context) {
    try {
      return context.read<KoalaAudioPlayer>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

/// The tinted square showing the letter, number or word a card is about.
class ActivityBadge extends StatelessWidget {
  const ActivityBadge({
    required this.text,
    this.size = 82,
    this.accent,
    super.key,
  });

  final String text;
  final double size;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final textDirection = LearningTextDirection.forText(text);
    final color = accent ?? Theme.of(context).colorScheme.primary;
    final baseStyle = size >= 72
        ? Theme.of(context).textTheme.headlineMedium
        : Theme.of(context).textTheme.titleLarge;
    final badgeStyle = LearningTextDirection.styleForText(
      baseStyle?.copyWith(fontWeight: FontWeight.w900, color: color),
      text,
    );

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: FittedBox(
              child: Directionality(
                textDirection: textDirection,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: badgeStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
