import 'package:flutter/material.dart';

import 'pyramid_3d.dart';

/// D-151: the one place both the main pyramid screen ([lib/widgets/
/// pyramid.dart]'s `Pyramid`) and the pyramid edit screen
/// ([lib/screens/editpyramid.dart]'s `EditPyramid`) build their six
/// pyramid blocks — found live, the hard way: those two screens used to
/// be entirely separate rendering pipelines (the edit screen ran six old,
/// flat 2D `CustomPainter`s nobody had migrated when the main screen was
/// rebuilt on [Pyramid3D]), so the edit screen looked categorically
/// different from — and worse than — the main screen, and every fix to
/// shared label-painting code only ever touched the one thing they still
/// had in common, never the actual defect. Owner: "get rid of the old
/// bullshit code that is in the edit screen and ... utilize the exact
/// same code as the main screen so that whenever the code changes in the
/// main screen, they will also change in the edit screen." Any future
/// visual change to [Pyramid3D] or to how block color is derived
/// automatically applies to both screens, because both call this same
/// class — there is no second implementation left to drift out of sync.
class PyramidStack extends StatelessWidget {
  final Future cat1Future;
  final Future cat2Future;
  final Future cat3Future;
  final Future cat4Future;
  final Future cat5Future;
  final Future cat6Future;
  final double size;
  final bool playEntranceSpin;

  /// Called with the tapped block's index (0-5, matching category
  /// position 1-6) and its resolved category data (`.cat`, `.pctComplete`)
  /// — the main screen navigates to that category's task list; the edit
  /// screen opens the rename/essence-edit sheet. `null` (the default)
  /// makes the pyramid non-interactive.
  final void Function(int index, dynamic category)? onCategoryTap;

  const PyramidStack({
    super.key,
    required this.cat1Future,
    required this.cat2Future,
    required this.cat3Future,
    required this.cat4Future,
    required this.cat5Future,
    required this.cat6Future,
    required this.size,
    this.onCategoryTap,
    this.playEntranceSpin = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait(
          [cat1Future, cat2Future, cat3Future, cat4Future, cat5Future, cat6Future]),
      builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (!snapshot.hasData) {
          return Pyramid3D(
            size: size,
            categories: List.generate(
              6,
              (i) => const PyramidCategoryData(label: '...', color: Colors.blue),
            ),
          );
        }

        final data = snapshot.data!;
        final tap = onCategoryTap;
        return Pyramid3D(
          size: size,
          playEntranceSpin: playEntranceSpin,
          categories: [
            for (final cat in data)
              PyramidCategoryData(label: cat.cat, color: setColor(cat.pctComplete)),
          ],
          onCategoryTap: tap == null ? null : (index) => tap(index, data[index]),
        );
      },
    );
  }
}

/// Maps a category completion percentage to its pyramid block color.
///
/// D-019 protects this function: tiered weighting must not change block
/// color. Despite eight branches this is effectively a four-band scale
/// (II-B). A negative [pctComplete] means no tasks are defined.
Color setColor(int pctComplete) {
  // If there are no tasks, pctComplete should be -1, so return blue
  if (pctComplete < 0) {
    return buildColor("#54B6FF"); // blue for no tasks
  }
  if (pctComplete >= 0 && pctComplete < 15) {
    return buildColor("#F96E6E"); // red
  } else if (pctComplete >= 15 && pctComplete < 30) {
    return buildColor("#F96E6E"); // red
  } else if (pctComplete >= 30 && pctComplete < 42) {
    return buildColor("#F96E6E"); // red
  } else if (pctComplete >= 42 && pctComplete < 55) {
    return buildColor("#F96E6E"); // red
  } else if (pctComplete >= 55 && pctComplete < 67) {
    return buildColor("#FFE177"); // yellow
  } else if (pctComplete >= 67 && pctComplete < 80) {
    return buildColor("#FFE177"); // yellow
  } else if (pctComplete >= 80 && pctComplete < 90) {
    return buildColor("#66CC5D"); // green
  } else if (pctComplete >= 90 && pctComplete <= 100) {
    return buildColor("#66CC5D"); // green
  } else {
    return buildColor("#54B6FF"); // blue (fallback)
  }
}

Color buildColor(String hex) {
  return Color(int.parse(hex.substring(1, 7), radix: 16) + 0xFF000000);
}
