import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-117: a pyramid-tier explainer screen shown once before the derived
/// categories, and in-place name+description editing on the categories
/// screen itself, which collapses the confirm/refine buttons to a single
/// "Next" once any edit is made — structural, matching this repo's
/// convention for setup_screen.dart (SetupService.instance is a live
/// singleton; not widget-tested directly, see setup_essence_flow_test.dart).
void main() {
  final source = File('lib/screens/setup_screen.dart').readAsStringSync();

  test(
      'D-117: Mira\'s readyToBuild routes through _Phase.tierIntro the '
      'first time, or straight to _Phase.categories once the explainer '
      'has already been shown this setup session', () {
    final start = source.indexOf('Future<void> _runMiraTurn()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  Future<void> _loadCategories', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(
        body,
        contains(
            '_phase = _tierIntroShown ? _Phase.categories : _Phase.tierIntro'));
  });

  test(
      'D-117: the tier-intro explainer\'s own Next button is what marks '
      'it seen and advances to the real categories screen', () {
    final start = source.indexOf('Widget _buildTierIntro()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  Widget _buildCategories', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(body, contains('_tierIntroShown = true'));
    expect(body, contains('_phase = _Phase.categories'));
  });

  test(
      'D-117: the tier-intro screen uses the shared OnboardingStyles type '
      'scale, matching D-102\'s essence-intro precedent, not a bespoke '
      'style reintroducing visual drift', () {
    final start = source.indexOf('Widget _buildTierIntro()');
    final end = source.indexOf('\n  Widget _buildCategories', start);
    final body = source.substring(start, end);

    expect(body, contains('OnboardingStyles.headline'));
    expect(body, contains('OnboardingStyles.primaryButton'));
    expect(body, contains('OnboardingStyles.accentDivider'));
  });

  test(
      'D-117: the tier-intro screen names all three tiers by their '
      'established terms — foundational, essential, peak (P-6/D-051), '
      'never invented labels', () {
    final start = source.indexOf('Widget _buildTierIntro()');
    final end = source.indexOf('\n  Widget _buildCategories', start);
    final body = source.substring(start, end);

    expect(body, contains('PEAK'));
    expect(body, contains('ESSENTIAL'));
    expect(body, contains('FOUNDATIONAL'));
  });

  test(
      'D-117: editing a category on the categories screen covers both '
      'name and description together, in one place — extends D-051\'s '
      '"adjust by tapping" and matches D-113\'s "wherever you can edit '
      'the category, you can edit the description too" principle', () {
    final start = source.indexOf('void _editCategory(int index)');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  }', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(body, contains('nameController'));
    expect(body, contains('descriptionController'));
    expect(body, contains('maxChars: 24'),
        reason: 'D-051\'s own name bound — a label, not a clause');
    expect(body, contains('maxChars: 140'),
        reason: 'the deriveCategories tool schema\'s own description bound');
  });

  test(
      'D-117: an edit only flips _categoriesEdited when the name or '
      'description actually changed — reopening Edit and saving without '
      'changing anything must not collapse the buttons', () {
    final start = source.indexOf('void _editCategory(int index)');
    final end = source.indexOf('\n  }', start);
    final body = source.substring(start, end);

    expect(body, contains('final changed ='));
    expect(body, contains('if (changed) _categoriesEdited = true'));
  });

  test(
      'D-117: the bare tap-to-rename interaction (_renameCategory, name '
      'only) is gone, replaced entirely by the combined name+description '
      'editor — having both would let the name be edited two '
      'inconsistent ways', () {
    expect(source, isNot(contains('void _renameCategory(')));
    expect(source, isNot(contains('_renameCategory(_categories.indexOf(c))')));
  });

  test(
      'D-117: each category card exposes an explicit Edit control, not '
      'only an implicit whole-card tap', () {
    final start = source.indexOf('Widget tierSection(');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n    }\n\n    return Padding(', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(body, contains("Text('Edit')"));
    expect(body, contains('_editCategory(_categories.indexOf(c))'));
  });

  test(
      'D-117: the bottom row collapses to a single Next once any card has '
      'been edited — regression test for the owner\'s explicit '
      'instruction: "if they actually make an edit to either a single '
      'category or description than the only option that will exist at '
      'the bottom is next"', () {
    final start = source.indexOf('Widget _buildCategories()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  Widget _buildEssences()', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    final ifIdx = body.indexOf('if (_categoriesEdited)');
    expect(ifIdx, greaterThan(-1));
    final elseIdx = body.indexOf('else', ifIdx);
    expect(elseIdx, greaterThan(ifIdx));

    final editedBranch = body.substring(ifIdx, elseIdx);
    expect(editedBranch, contains("Text('Next')"));
    expect(editedBranch, isNot(contains('Not quite right')));

    final unEditedBranch = body.substring(elseIdx);
    expect(unEditedBranch, contains('Not quite right'));
    expect(unEditedBranch, contains('This feels right'));
  });

  test(
      'D-117: _categoriesEdited resets whenever a fresh or refined '
      'proposal is derived — an edit from a discarded earlier proposal '
      'must not carry over and suppress the buttons on a new one', () {
    final start = source.indexOf('Future<void> _runMiraTurn()');
    final end = source.indexOf('\n  Future<void> _loadCategories', start);
    final body = source.substring(start, end);

    final occurrences = '_categoriesEdited = false'.allMatches(body).length;
    expect(occurrences, greaterThanOrEqualTo(2),
        reason: 'both the readyToBuild path and the SetupCallLimitException '
            'fallback path must reset it');
  });
}
