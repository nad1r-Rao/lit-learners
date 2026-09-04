import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/app.dart';

void main() {
  testWidgets('LittleLearnersApp shows responsive splash and opens login',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalOnError = FlutterError.onError;
    final layoutErrors = <FlutterErrorDetails>[];
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        layoutErrors.add(details);
      } else {
        originalOnError?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(const LittleLearnersApp());
    // Fixed pumps rather than pumpAndSettle: the splash breathes on a
    // loop now, so it never settles. Long enough for the session check
    // to finish and the entrance to land.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('LITTLE\nLEARNERS'), findsOneWidget);
    expect(find.text('Play, learn and grow together'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(layoutErrors, isEmpty);

    await tester.tap(find.byKey(const ValueKey('splash-continue-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('PARENT'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
