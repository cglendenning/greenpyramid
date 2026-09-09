import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-118: the vision statement moves to right after the opening
/// conversation concludes, shown on its own screen before the tier
/// explainer/categories, with a fixed "I'm the kind of person that"
/// opener — structural, matching this repo's convention for
/// setup_screen.dart (SetupService.instance is a live singleton; not
/// widget-tested directly, see setup_essence_flow_test.dart).
void main() {
  final source = File('lib/screens/setup_screen.dart').readAsStringSync();

  test(
      'D-118: the real conclusion of the opening conversation (never a '
      'refinement round) routes through _Phase.openingVision before the '
      'tier explainer/categories', () {
    final start = source.indexOf(
        'Future<void> _proceedFromReadyToBuild(');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  Future<void> _deriveOpeningVisionStatement', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(body, contains('if (priorCategories == null)'));
    expect(body, contains('_phase = _Phase.openingVision'));
    expect(body, contains('_deriveOpeningVisionStatement()'));
  });

  test(
      'D-118: a refinement round\'s conclusion (priorCategories non-null) '
      'is unaffected — straight to the tier explainer/categories, no '
      'second vision-statement moment', () {
    final start = source.indexOf('Future<void> _proceedFromReadyToBuild(');
    final end = source.indexOf('\n  Future<void> _deriveOpeningVisionStatement', start);
    final body = source.substring(start, end);

    final elseIdx = body.indexOf('return;\n    }');
    expect(elseIdx, greaterThan(-1));
    final afterEarlyReturn = body.substring(elseIdx);
    expect(afterEarlyReturn,
        contains('_phase = _tierIntroShown ? _Phase.categories : _Phase.tierIntro'));
    expect(afterEarlyReturn, contains('_loadCategories(existingCategories: priorCategories)'));
  });

  test(
      'D-118: the opening-vision screen\'s own Next fires the category '
      'derivation and advances into the tier explainer (or straight to '
      'categories if already shown this session, matching D-117)', () {
    final start = source.indexOf('Future<void> _proceedFromOpeningVision()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  }', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(body,
        contains('_phase = _tierIntroShown ? _Phase.categories : _Phase.tierIntro'));
    expect(body, contains('_loadCategories()'));
  });

  test(
      'D-118: the opening-vision screen shows a real loading state while '
      'generation is in flight, and uses the shared OnboardingStyles type '
      'scale once it has the statement, matching D-102/D-117\'s '
      'precedent', () {
    final start = source.indexOf('Widget _buildOpeningVision()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n  Widget _buildTierIntro()', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(body, contains('_visionStatement == null'));
    expect(body, contains('CircularProgressIndicator'));
    expect(body, contains('OnboardingStyles.headline'));
    expect(body, contains('OnboardingStyles.primaryButton'));
    expect(body, contains('_proceedFromOpeningVision'));
  });

  test(
      'D-118: the setup-completion flow no longer generates a second '
      'vision statement — closeSynthesis is gone, replaced by directly '
      'ending the session, since deriveOpeningVisionStatement already '
      'wrote the one and only vision statement earlier in the same '
      'setup', () {
    expect(source, isNot(contains('closeSynthesis')));
    final start = source.indexOf('Future<void> _confirmHabitsAndClose()');
    expect(start, greaterThan(-1));
    final end = source.indexOf('\n    } on AiBudgetException', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);
    expect(body, contains('CouncilService.instance.endSession('));
  });

  test(
      'D-118: the tier-intro screen now also explains why the hierarchy '
      'matters for habits — a foundational miss carries more weight than '
      'a peak one (D-020), not just what the three tiers are named', () {
    final start = source.indexOf('Widget _buildTierIntro()');
    final end = source.indexOf('\n  Widget _buildCategories', start);
    final body = source.substring(start, end);

    expect(body, contains('Every habit you build lives inside one of these tiers'));
  });
}
