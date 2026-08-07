import 'package:flutter/foundation.dart';

/// The result of checking one traced glyph against its dotted guide.
@immutable
class TraceScore {
  const TraceScore({
    required this.coverage,
    required this.precision,
    required this.score,
    required this.hasInk,
  });

  const TraceScore.empty()
      : coverage = 0,
        precision = 0,
        score = 0,
        hasInk = false;

  /// Fraction of the dotted letter the child covered (0..1).
  final double coverage;

  /// Fraction of the child's ink that landed on or near the letter (0..1).
  final double precision;

  /// Combined 0..100 mark, fed into the same progress pipeline as quiz scores.
  final int score;

  /// False when the canvas was blank, so "check" can ask for a try first.
  final bool hasInk;

  bool passed(int passingScore) => hasInk && score >= passingScore;

  /// Encouraging, specific feedback for a toddler and the adult beside them.
  String feedback(int passingScore) {
    if (!hasInk) return 'Draw on the dots first, then check your work.';
    if (score >= 90) return 'Beautiful tracing. You stayed right on the dots.';
    if (score >= 75) return 'Great tracing. Almost perfect.';
    if (score >= passingScore) return 'Nice work. You followed the letter.';
    if (coverage < 0.45) {
      return 'Try again and trace the whole letter from start to end.';
    }
    if (precision < 0.6) return 'Try again and keep your line on the dots.';
    return 'Close. Trace slowly along the dots and try once more.';
  }

  @override
  String toString() {
    return 'TraceScore(score: $score, coverage: '
        '${coverage.toStringAsFixed(2)}, precision: '
        '${precision.toStringAsFixed(2)})';
  }
}
