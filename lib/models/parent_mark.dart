import 'package:flutter/material.dart';

/// How a grown-up grades a finished drawing or tracing page.
///
/// Canvas work is the one activity the app does not mark itself: it cannot tell
/// a careful house from a scribbled one, and a toddler's best effort is a thing
/// a parent recognises and software does not. Each grade maps onto the same
/// 0-100 scale every other activity reports, so stars, reports, the leaderboard
/// and the passing rules need no special case for canvas levels.
///
/// The four values are chosen so that, across every drawing and tracing level in
/// the app, exactly one grade fails and each of the others is worth one more
/// star than the last.
enum ParentMark { needsPractice, goodTry, greatWork, perfect }

extension ParentMarkValue on ParentMark {
  /// Below every canvas level's passing score for [needsPractice], at or above
  /// all of them for the rest.
  int get score => switch (this) {
        ParentMark.needsPractice => 45,
        ParentMark.goodTry => 70,
        ParentMark.greatWork => 85,
        ParentMark.perfect => 100,
      };

  String get label => switch (this) {
        ParentMark.needsPractice => 'Needs practice',
        ParentMark.goodTry => 'Good try',
        ParentMark.greatWork => 'Great work',
        ParentMark.perfect => 'Perfect',
      };

  String get description => switch (this) {
        ParentMark.needsPractice => 'Not finished yet. Try this level again.',
        ParentMark.goodTry => 'Got there, with room to improve.',
        ParentMark.greatWork => 'Neat, and mostly where it should be.',
        ParentMark.perfect => 'Could not have been done better.',
      };

  IconData get icon => switch (this) {
        ParentMark.needsPractice => Icons.refresh_rounded,
        ParentMark.goodTry => Icons.thumb_up_alt_outlined,
        ParentMark.greatWork => Icons.star_rounded,
        ParentMark.perfect => Icons.emoji_events_rounded,
      };

  /// Stars this grade earns, matching the rule in the progress repository.
  int get stars => switch (this) {
        ParentMark.needsPractice => 0,
        ParentMark.goodTry => 1,
        ParentMark.greatWork => 2,
        ParentMark.perfect => 3,
      };

  /// Whether this grade lets the child move on from a level that needs
  /// [passingScore] to pass.
  bool passes(int passingScore) => score >= passingScore;
}
