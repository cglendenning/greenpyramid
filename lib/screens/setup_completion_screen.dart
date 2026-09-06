import 'package:flutter/material.dart';

import '../services/db.dart';
import '../theme/app_colors.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/pyramid.dart' show setColor;
import '../widgets/pyramid_3d.dart';

/// D-046: the completion moment, sequenced after D-055's closing synthesis.
/// The real main-screen pyramid (not a bespoke celebration graphic),
/// confetti (D-066's single sanctioned exception), and a 3-second
/// decelerating spin. Skippable by tapping; respects reduce-motion.
class SetupCompletionScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SetupCompletionScreen({super.key, required this.onDone});

  @override
  State<SetupCompletionScreen> createState() => _SetupCompletionScreenState();
}

class _SetupCompletionScreenState extends State<SetupCompletionScreen> {
  late Future<List<Map<String, dynamic>>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = DatabaseHelper.instance.queryCategories();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.82;
    return GestureDetector(
      onTap: widget.onDone,
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
                    final rows = snapshot.data!
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
                            // Freshly committed habits, nothing checked off
                            // yet today — the real, current completion
                            // state, not a placeholder.
                            color: setColor(0),
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
