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

    testWidgets(
        'D-107: the pulse actually animates in the normal (motion-enabled) '
        'case — regression test for a defect found live in TypingIndicator\'s '
        'copy of this exact pattern: "reduceMotion == _reduceMotion" as the '
        'sole didChangeDependencies guard meant the very first call — the '
        'overwhelmingly common case, where the real value is also false — '
        'short-circuited before ever calling _pulse.repeat(), so the '
        'pyramid rendered but was frozen at the controller\'s initial '
        'value forever, in every real build that ever shipped',
        (tester) async {
      await tester.pumpWidget(wrap(const SetupProgressIndicator(progress: 0.5)));
      await tester.pump();

      // Matrix4.getMaxScaleOnAxis() doesn't isolate the scale component
      // from Transform.scale's combined (translate * scale * translate⁻¹)
      // matrix — it read a constant 1.0 regardless of the actual pulse
      // value even against the known-fixed widget, which is what this
      // test is guarding against. The raw x-scale entry of the matrix
      // (storage[0]) is what Transform.scale actually sets.
      double scale() => tester
          .widget<Transform>(find.descendant(
              of: find.byType(SetupProgressIndicator),
              matching: find.byType(Transform)))
          .transform
          .storage[0];

      final before = scale();
      await tester.pump(const Duration(milliseconds: 400));
      final after = scale();

      expect(after, isNot(closeTo(before, 0.0001)),
          reason: 'the pulse must actually be running, not frozen at its '
              'initial value — this is exactly what shipped broken');
    });
  });
}
