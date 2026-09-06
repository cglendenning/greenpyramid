import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/widgets/setup_progress_indicator.dart';

Widget wrap(Widget child, {bool disableAnimations = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('D-044: the setup progress indicator', () {
    testWidgets('D-044: renders at a fixed size regardless of progress',
        (tester) async {
      await tester.pumpWidget(wrap(const SetupProgressIndicator(progress: 0.0, size: 48)));
      expect(find.byType(SetupProgressIndicator), findsOneWidget);
      final box = tester.getSize(find.byType(SetupProgressIndicator));
      expect(box.width, 48);
      expect(box.height, 48);
    });

    testWidgets('D-044: progress values outside 0-1 do not throw',
        (tester) async {
      await tester.pumpWidget(wrap(const SetupProgressIndicator(progress: -0.5)));
      await tester.pump();
      await tester.pumpWidget(wrap(const SetupProgressIndicator(progress: 1.5)));
      await tester.pump();
    });

    testWidgets('D-044: respects reduce-motion — no pulsing animation ticks',
        (tester) async {
      await tester.pumpWidget(
          wrap(const SetupProgressIndicator(progress: 0.5), disableAnimations: true));
      // With animations disabled, a pump with a duration should not need
      // repeated frames to settle — pumpAndSettle should return quickly
      // rather than timing out on a repeating animation.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });
  });
}
