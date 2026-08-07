import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/viewmodels/level_activity_viewmodel.dart';
import 'package:little_learners/views/child_dashboard/canvas_level_view.dart';
import 'package:little_learners/widgets/drawing/drawing_canvas.dart';
import 'package:provider/provider.dart';

void main() {
  group('DrawingLevelView', () {
    testWidgets('a step can only be finished after new marks are made',
        (tester) async {
      await tester.pumpWidget(_host(DrawingLevelView(
        level: _drawingLevel(),
        onFinish: () {},
      )));

      expect(find.text('Draw on the page to finish this step.'), findsOneWidget);
      expect(_button(tester, 'I finished this step').onPressed, isNull);

      await _scribble(tester);

      expect(_button(tester, 'I finished this step').onPressed, isNotNull);

      await tester.tap(find.text('I finished this step'));
      await tester.pumpAndSettle();

      expect(find.text('Next step'), findsOneWidget);
    });

    testWidgets('the picture is kept across steps but each step needs new ink',
        (tester) async {
      await tester.pumpWidget(_host(DrawingLevelView(
        level: _drawingLevel(),
        onFinish: () {},
      )));

      await _scribble(tester);
      await tester.tap(find.text('I finished this step'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next step'));
      await tester.pumpAndSettle();

      // Second prompt: the earlier strokes are still on the page, but they do
      // not count towards this step.
      expect(find.text('Draw the sky at the top of your page.'), findsNothing);
      expect(find.text('Draw a house under the sky.'), findsOneWidget);
      expect(_button(tester, 'I finished this step').onPressed, isNull);

      await _scribble(tester, from: const Offset(180, 320));

      expect(_button(tester, 'I finished this step').onPressed, isNotNull);
    });

    testWidgets('every drawing tool is offered', (tester) async {
      await tester.pumpWidget(_host(DrawingLevelView(
        level: _drawingLevel(),
        onFinish: () {},
      )));

      expect(find.text('Pen'), findsOneWidget);
      expect(find.text('Pencil'), findsOneWidget);
      expect(find.text('Brush'), findsOneWidget);
      expect(find.text('Marker'), findsOneWidget);
      expect(find.text('Eraser'), findsOneWidget);
    });
  });

  group('TracingLevelView', () {
    testWidgets('shows the letter, the guide and a check action',
        (tester) async {
      await _pumpTracing(tester);

      expect(find.text('A'), findsOneWidget);
      expect(find.text('Trace the letter A.'), findsOneWidget);
      expect(find.text('Check my tracing'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // The eraser is offered, the highlighter is not: it would not help here.
      expect(find.text('Eraser'), findsOneWidget);
      expect(find.text('Marker'), findsNothing);
    });

    testWidgets('checking a blank canvas asks the child to draw first',
        (tester) async {
      await _pumpTracing(tester);

      await tester.tap(find.text('Check my tracing'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(_settle));
      await tester.pumpAndSettle();

      expect(
        find.text('Draw on the dots first, then check your work.'),
        findsOneWidget,
      );
      expect(find.text('Check my tracing'), findsOneWidget);
    });

    testWidgets('a traced letter is graded and unlocks the next one',
        (tester) async {
      await _pumpTracing(tester);

      final canvas = tester.getRect(find.byType(DrawingCanvas));
      // Where TraceGlyph puts the guide: centred, filling most of the shorter
      // side. Colouring it in is what a well-traced letter looks like.
      final guide = Rect.fromCenter(
        center: canvas.center,
        width: canvas.shortestSide * 0.7,
        height: canvas.shortestSide * 0.7,
      );

      // Grading rasterises the canvas, which is real async work: it has to be
      // started inside runAsync or it never completes under the fake clock.
      await tester.runAsync(() async {
        for (var y = guide.top; y <= guide.bottom; y += 8) {
          await tester.dragFrom(
            Offset(guide.left, y),
            Offset(guide.width, 0),
          );
        }
        await tester.tap(find.text('Check my tracing'));
        await Future<void>.delayed(_settle);
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('% on the dots'), findsOneWidget);
      expect(find.textContaining('Traced '), findsOneWidget);
      expect(find.text('Next letter'), findsOneWidget);
      expect(find.text('Check my tracing'), findsNothing);
    });
  });
}

const _settle = Duration(milliseconds: 400);

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: ChangeNotifierProvider<LevelActivityViewModel>(
        create: (_) => LevelActivityViewModel(
          child is TracingLevelView ? _tracingLevel() : _drawingLevel(),
        ),
        child: child,
      ),
    ),
  );
}

Future<void> _pumpTracing(WidgetTester tester) async {
  await tester.pumpWidget(_host(TracingLevelView(
    level: _tracingLevel(),
    onFinish: () {},
  )));
  // Fitting the glyph rasterises it, which needs real async time.
  await tester.runAsync(() => Future<void>.delayed(_settle));
  await tester.pumpAndSettle();
}

Future<void> _scribble(
  WidgetTester tester, {
  Offset from = const Offset(150, 300),
}) async {
  await tester.dragFrom(from, const Offset(60, 40));
  await tester.pumpAndSettle();
}

FilledButton _button(WidgetTester tester, String label) {
  return tester.widget<FilledButton>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(FilledButton),
    ),
  );
}

LearningLevel _drawingLevel() {
  return const LearningLevel(
    id: 'drawing-test',
    moduleId: 'drawing',
    stage: 4,
    levelNumber: 1,
    title: 'Picture Prompts',
    subtitle: 'Build a picture',
    type: LevelType.drawing,
    passingScore: 60,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Sky',
        prompt: 'Draw the sky at the top of your page.',
        displayText: 'Sky',
        visualLabel: 'Sky drawing prompt',
      ),
      ContentItem(
        title: 'House',
        prompt: 'Draw a house under the sky.',
        displayText: 'House',
        visualLabel: 'House drawing prompt',
      ),
    ],
  );
}

LearningLevel _tracingLevel() {
  return const LearningLevel(
    id: 'tracing-test',
    moduleId: 'english',
    stage: 3,
    levelNumber: 1,
    title: 'Trace A B',
    subtitle: 'Trace',
    type: LevelType.tracing,
    passingScore: 50,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Letter A',
        prompt: 'Trace the letter A.',
        displayText: 'A',
        visualLabel: 'Dotted letter A',
      ),
      ContentItem(
        title: 'Letter B',
        prompt: 'Trace the letter B.',
        displayText: 'B',
        visualLabel: 'Dotted letter B',
      ),
    ],
  );
}
