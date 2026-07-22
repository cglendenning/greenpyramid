// One-off performance trace for the home-screen pyramid spin, run on a real
// low-end device to get authoritative UI/raster frame timings instead of
// guessing from source. Run with:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/pyramid_perf_test.dart -d <device-id> \
//     --profile
// Summary (build vs raster thread times, GC counts) lands in
// build/integration_response_data.json under the "pyramid_spin" key.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/src/frame_timing_summarizer.dart';
import 'package:integration_test/integration_test.dart';
import 'package:life_ops/pyramid_3d.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pyramid spin frame timing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(builder: (context) {
            final width = MediaQuery.of(context).size.width * 0.87;
            return Pyramid3D(
              size: width,
              categories: const [
                PyramidCategoryData(label: 'Health', color: Colors.green),
                PyramidCategoryData(label: 'Mindset', color: Colors.blue),
                PyramidCategoryData(label: 'Empty3', color: Colors.orange),
                PyramidCategoryData(label: 'Empty4', color: Colors.purple),
                PyramidCategoryData(label: 'Empty5', color: Colors.red),
                PyramidCategoryData(label: 'Empty6', color: Colors.teal),
              ],
            );
          }),
        ),
      ),
    ));
    // Let the stone texture finish loading so steady-state frames (not the
    // one-time decode) are what gets measured.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final center = tester.getCenter(find.byType(Pyramid3D));

    // Collect raw per-frame engine timings directly (bypassing
    // binding.watchPerformance, which also opens a VM-service websocket for
    // GC counts that isn't reachable in this drive setup) and summarize with
    // the same FrameTimingSummarizer flutter_driver perf tests use.
    final frameTimings = <FrameTiming>[];
    final watcher = frameTimings.addAll;
    await Future<void>.delayed(const Duration(seconds: 1)); // flush stale timings
    SchedulerBinding.instance.addTimingsCallback(watcher);

    // Five drag-and-fling spins back to back, matching how a user actually
    // spins the pyramid (a fast horizontal swipe that then coasts via the
    // settle animation) rather than one single frame-by-frame drag.
    for (var i = 0; i < 5; i++) {
      await tester.fling(
        find.byType(Pyramid3D),
        Offset((i.isEven ? -1 : 1) * 300, 0),
        2500,
      );
      await tester.pump();
      // Pump real-ish frame deltas through the whole settle animation
      // instead of pumpAndSettle, so every intermediate frame renders for
      // real rather than being collapsed.
      for (var f = 0; f < 90; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    // Exercise a raw continuous drag too (worst case: a frame per pixel of
    // finger movement, no settle physics smoothing anything out).
    final gesture = await tester.startGesture(center);
    for (var i = 0; i < 60; i++) {
      await gesture.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    for (var f = 0; f < 60; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    await Future<void>.delayed(const Duration(seconds: 1)); // flush trailing timings
    SchedulerBinding.instance.removeTimingsCallback(watcher);

    final summary = FrameTimingSummarizer(frameTimings).summary;
    summary['frame_count'] = frameTimings.length;
    binding.reportData = {'pyramid_spin': summary};
  });
}
