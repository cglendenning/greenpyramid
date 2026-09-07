import 'dart:async';

import 'package:flutter/material.dart';

import '../services/db.dart';
import '../theme/app_colors.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/pyramid_3d.dart';

/// D-046: the completion moment, sequenced after D-055's closing synthesis.
/// The real main-screen pyramid (not a bespoke celebration graphic),
/// confetti (D-066's single sanctioned exception), and a 3-second
/// decelerating spin. Skippable by tapping; respects reduce-motion.
class SetupCompletionScreen extends StatefulWidget {
  final VoidCallback onDone;
  // Injectable for tests: the real query goes through sqflite's platform
  // channel, which needs genuine wall-clock time to resolve and makes
  // this screen's auto-advance timing untestable in bounded, deterministic
  // pumps. Defaults to the real singleton for actual use.
  final Future<List<Map<String, dynamic>>> Function() queryCategories;
  SetupCompletionScreen(
      {super.key,
      required this.onDone,
      Future<List<Map<String, dynamic>>> Function()? queryCategories})
      : queryCategories =
            queryCategories ?? DatabaseHelper.instance.queryCategories;

  @override
  State<SetupCompletionScreen> createState() => _SetupCompletionScreenState();
}

class _SetupCompletionScreenState extends State<SetupCompletionScreen> {
  late Future<List<Map<String, dynamic>>> _categories;
  Timer? _autoAdvance;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _categories = widget.queryCategories();
    // D-046's own text — "settles" after the 3-second spin, "skippable by
    // tapping" — describes an otherwise-automatic transition a tap can
    // shortcut, not a screen that waits forever for one. This was
    // previously the only way forward at all: nothing ever called
    // onDone() without a tap. A generous margin past the 3-second spin so
    // it never fires mid-animation, and independent of whatever the
    // pyramid itself is doing — a render failure inside it must never be
    // able to strand the user here permanently.
    _autoAdvance = Timer(const Duration(seconds: 5), _advance);
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    super.dispose();
  }

  void _advance() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.82;
    return GestureDetector(
      onTap: _advance,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _categories,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    // db.query()'s result is sqflite's own read-only list on
                    // the real platform channel (confirmed live: calling
                    // .sort() on it directly throws
                    // "Unsupported operation: read-only" during build,
                    // before the Scaffold ever paints — this is what a
                    // blank white completion screen actually was).
                    final rows = List<Map<String, dynamic>>.from(snapshot.data!)
                      ..sort((a, b) =>
                          (a[DatabaseHelper.columnPosition] as int? ?? 0)
                              .compareTo(
                                  b[DatabaseHelper.columnPosition] as int? ?? 0));
                    return Pyramid3D(
                      size: size,
                      playEntranceSpin: true,
                      categories: [
                        for (final row in rows)
                          PyramidCategoryData(
                            label: row[DatabaseHelper.columnCat] as String? ?? '',
                            // Green here is deliberately not the real
                            // completion color (which is red at 0% —
                            // correct on the home screen, since nothing
                            // has been checked off yet). This is the
                            // one-time celebration moment: the pyramid was
                            // just built, and green reads as "done," not
                            // as a completion percentage.
                            color: AppColors.brandGreen,
                          ),
                      ],
                    );
                  },
                ),
              ),
              const ConfettiOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}
