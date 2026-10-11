import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: NordicTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('NordicButton shows spinner and ignores taps while loading', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        NordicButton(label: 'Go', isLoading: true, onPressed: () => taps++),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Go'), findsNothing);
    await tester.tap(find.byType(NordicButton));
    expect(taps, 0);
  });

  testWidgets('NordicButton fires onPressed when enabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(NordicButton(label: 'Go', onPressed: () => taps++)),
    );
    await tester.tap(find.text('Go'));
    expect(taps, 1);
  });

  testWidgets(
    'NordicRatingStars reports tapped value and renders filled stars',
    (tester) async {
      int? picked;
      await tester.pumpWidget(
        _wrap(NordicRatingStars(value: 2, onChanged: (v) => picked = v)),
      );
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(3));
      await tester.tap(find.byKey(const ValueKey('star_5')));
      expect(picked, 5);
    },
  );

  testWidgets('NordicRatingStars is read-only without onChanged', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const NordicRatingStars(value: 4)));
    await tester.tap(find.byKey(const ValueKey('star_1')), warnIfMissed: false);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
  });

  testWidgets('NordicTextField toggles password visibility', (tester) async {
    await tester.pumpWidget(
      _wrap(const NordicTextField(label: 'Password', obscureText: true)),
    );
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isFalse,
    );
  });

  testWidgets('Design kit demo screen builds', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: NordicTheme.light(),
        home: const DesignKitDemoScreen(),
      ),
    );
    expect(find.text('Design kit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
