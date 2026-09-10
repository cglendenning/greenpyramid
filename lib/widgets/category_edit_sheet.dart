import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// D-113: one shared editor for a category's name and description —
/// reachable both from the pyramid's own edit mode (`editpyramid.dart`)
/// and the category detail screen (`tasklist.dart`), which previously had
/// two separate, inconsistent dialogs that only ever let the person
/// change one field or the other: `editpyramid.dart` renamed the category
/// but had no way to touch its description; `tasklist.dart` edited the
/// description (as "your essence" — P-12's internal spec term, never
/// meant for user-facing copy, the same confusion already fixed once on
/// the essence-deepening screen but never carried through here) with no
/// way to rename the category. Found live: "wherever I can edit the
/// category, I should also be able to edit the description of the
/// category."
///
/// A rounded, dark modal sheet — not the plain default `AlertDialog` both
/// callers used before — matching this app's established palette
/// (`AppColors`) and Raleway type scale, per the owner's explicit ask to
/// make category editing "more beautiful."
class CategoryEditResult {
  final String name;
  // D-127: always the field's final text, empty string included — never
  // collapsed to null. Null here used to mean "field was empty," which a
  // caller couldn't tell apart from "field was left untouched," so
  // clearing a description to blank and saving silently did nothing.
  final String description;
  const CategoryEditResult({required this.name, required this.description});
}

Future<CategoryEditResult?> showCategoryEditSheet(
  BuildContext context, {
  required String currentName,
  String? currentDescription,
}) {
  return showModalBottomSheet<CategoryEditResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CategoryEditSheet(
      currentName: currentName,
      currentDescription: currentDescription,
    ),
  );
}

class _CategoryEditSheet extends StatefulWidget {
  final String currentName;
  final String? currentDescription;
  const _CategoryEditSheet({required this.currentName, this.currentDescription});

  @override
  State<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<_CategoryEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _descriptionController =
        TextEditingController(text: widget.currentDescription ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(CategoryEditResult(
      name: name,
      description: _descriptionController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Edit category',
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'NAME',
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            _EditField(
              controller: _nameController,
              maxLength: 30,
              maxLines: 1,
              hintText: 'Category name',
            ),
            const SizedBox(height: 20),
            const Text(
              'DESCRIPTION',
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            _EditField(
              controller: _descriptionController,
              maxLength: 400,
              maxLines: 4,
              hintText: 'Why this category matters to you',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontFamily: 'Raleway', color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final int maxLines;
  final String hintText;

  const _EditField({
    required this.controller,
    required this.maxLength,
    required this.maxLines,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        autofocus: maxLines == 1,
        style: const TextStyle(
            fontFamily: 'Raleway', color: AppColors.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          border: InputBorder.none,
          counterStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
