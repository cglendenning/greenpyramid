import 'package:flutter/material.dart';
import 'package:life_ops/services/db.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/widgets/category_edit_sheet.dart';
import 'package:life_ops/widgets/onboarding_backdrop.dart';
import 'package:life_ops/widgets/pyramid_stack.dart';

/// D-151: this screen used to render six flat, static, old CustomPainters
/// (`DrawCat1`..`DrawCat6`) — a separate rendering pipeline nobody
/// migrated when the main pyramid screen (`lib/widgets/pyramid.dart`) was
/// rebuilt on the real 3D `Pyramid3D` widget, so this screen looked
/// categorically different from, and worse than, the main one. Owner:
/// "get rid of the old bullshit code that is in the edit screen and ...
/// utilize the exact same code as the main screen so that whenever the
/// code changes in the main screen, they will also change in the edit
/// screen." This screen now renders the exact same [PyramidStack] the
/// main screen does — same 3D pyramid, same drag/spin, same
/// completion-percentage-driven block colors (`setColor`, D-019) — the
/// only difference is what a tap does: the main screen navigates to a
/// category's task list; this screen opens the rename/essence-edit sheet.
class EditPyramid extends StatefulWidget {
  final Future cat1Future;
  final Future cat2Future;
  final Future cat3Future;
  final Future cat4Future;
  final Future cat5Future;
  final Future cat6Future;

  // D-151: after a rename/essence edit, the underlying category futures
  // must actually be refreshed for the new name to appear — both here and
  // on the main pyramid screen, since both now render from the exact same
  // futures. Mirrors Pyramid's own onReturnFromTaskList refresh pattern.
  final VoidCallback? onCategoryEdited;

  const EditPyramid(this.cat1Future, this.cat2Future, this.cat3Future,
      this.cat4Future, this.cat5Future, this.cat6Future,
      {super.key, this.onCategoryEdited});

  @override
  State<EditPyramid> createState() => _EditPyramid();
}

class _EditPyramid extends State<EditPyramid> {
  final dbHelper = DatabaseHelper.instance;

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'editpyramid');

    double pyramidWidth = MediaQuery.of(context).size.width * 0.87;

    var mainTextStyle = const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        fontFamily: 'Exo2',
        color: AppColors.textPrimary);

    // D-152: found live — a bare Column here (unlike the main screen's,
    // which sits inside a SingleChildScrollView matching the full
    // viewport width) sizes itself to its widest child instead of the
    // screen's width, and nothing then centers that narrower column
    // within the Scaffold body — so it renders flush against the left
    // edge, not centered, visibly shifting the pyramid left of where the
    // main screen puts it. Align(topCenter) — the same alignment
    // _jungleScene already uses for the main screen's pyramid — centers
    // this column regardless of its own width, matching the main screen
    // exactly.
    return OnboardingBackdrop(
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(height: pyramidWidth * 0.82 * .1),
          Text(
            'Green Pyramid (Edit)',
            style: mainTextStyle,
          ),
          SizedBox(height: pyramidWidth * 0.82 * .2),
          PyramidStack(
            cat1Future: widget.cat1Future,
            cat2Future: widget.cat2Future,
            cat3Future: widget.cat3Future,
            cat4Future: widget.cat4Future,
            cat5Future: widget.cat5Future,
            cat6Future: widget.cat6Future,
            size: pyramidWidth,
            editable: true,
            onCategoryTap: (index, category) =>
                showEditDialog(context, index + 1, category.cat),
          ),
        ]),
      ),
    );
  }

  // D-113: name and description together, in one shared, styled sheet —
  // replacing the old plain AlertDialog that only ever touched the name.
  Future<void> showEditDialog(
      BuildContext context, int categoryid, String category) async {
    final currentEssence = await dbHelper.getLatestEssenceForCategory(categoryid);
    if (!mounted) return;
    final result = await showCategoryEditSheet(
      context,
      currentName: category,
      currentDescription: currentEssence,
    );
    if (result == null) return;

    // D-113: found live — renaming a category used to call
    // deleteCategoryContents(category) *before* renameCategoryCascading,
    // wiping every task and task-log row for the old name first. The
    // cascade that followed then had nothing left to move — D-084's fix
    // for exactly this ("renaming without cascading orphans every habit
    // and log row") was being silently defeated by a leftover call to the
    // pre-D-084 destructive path. Renaming a category to fix a typo was
    // permanently deleting its entire habit history. Removed — the
    // cascade alone is correct and sufficient.
    if (result.name != category) {
      await dbHelper.renameCategoryCascading(
        categoryid: categoryid,
        newName: result.name,
      );
    }
    // D-127: compare against what was actually loaded, not against
    // null/empty — an intentionally-cleared description is itself a
    // change and must be persisted, not skipped because it's blank.
    if (result.description != (currentEssence ?? '')) {
      await dbHelper.insertCategoryEssence(
        categoryId: categoryid,
        essence: result.description,
      );
    }

    widget.onCategoryEdited?.call();
  }
}
