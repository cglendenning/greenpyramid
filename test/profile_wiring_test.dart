import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-089: profile.dart's vision-statement regeneration and 30-day
/// progress analysis are Claude-backed via ProfileService, gated by
/// D-014's entitlement check like every other non-setup AI surface —
/// structural, matching this repo's convention for screens built on live
/// singletons (setup_screen.dart, editpyramid.dart, tasklist.dart aren't
/// directly widget-tested elsewhere either).
void main() {
  test(
      'D-089: profile.dart no longer imports the legacy OpenAI transport — '
      'regression test for the root cause found live via Cloud Run logs: '
      'this screen was still calling a defunct OpenAI account with zero '
      'credits, the one AI surface D-053/D-066\'s retirement of the legacy '
      'AI screens missed', () {
    final source = File('lib/screens/profile.dart').readAsStringSync();
    expect(source, isNot(contains('ai_proxy_client.dart')));
    expect(source, isNot(contains('AiProxy.instance')));
  });

  test('D-089: profile.dart routes both AI actions through ProfileService', () {
    final source = File('lib/screens/profile.dart').readAsStringSync();
    expect(source, contains('ProfileService'));
    expect(source, contains('_profile.regenerateVisionStatement()'));
    expect(source, contains('_profile.generateProgressAnalysis()'));
  });

  test(
      'D-089/D-014: both AI actions are gated by the shared ensureEntitled '
      'gate before the call, routing an unentitled account to the paywall '
      'first — the same pattern every other non-setup AI surface uses. '
      'Uses the shared entitlement_gate.dart helper rather than its own '
      'private copy — found live during this same change that this '
      'screen had drifted into duplicating that exact function', () {
    final source = File('lib/screens/profile.dart').readAsStringSync();
    expect(source,
        contains("import 'package:life_ops/services/entitlement_gate.dart';"));
    expect(source, contains('PaywallScreen('));
    expect(source, isNot(contains('Future<bool> _ensureEntitled')),
        reason:
            'must use the shared ensureEntitled(), not a private duplicate');
    final regenIdx = source.indexOf('_regenerateVisionStatement()');
    final analysisIdx = source.indexOf('_generateProgressAnalysis()');
    final ensureIdx = source.indexOf('ensureEntitled(context');
    expect(regenIdx, greaterThan(-1));
    expect(analysisIdx, greaterThan(-1));
    expect(ensureIdx, greaterThan(-1));
  });

  test(
      'D-089: the 30-day progress analysis is an explicit button tap, not '
      'an automatic call fired on screen open — the legacy version fired '
      'two unconditional AI calls in initState() every time this screen '
      'opened, before any entitlement or cost check ran', () {
    final source = File('lib/screens/profile.dart').readAsStringSync();
    final initStateStart = source.indexOf('void initState()');
    final initStateEnd = source.indexOf('\n  }', initStateStart);
    final initStateBody = source.substring(
        initStateStart, initStateEnd == -1 ? source.length : initStateEnd);
    expect(initStateBody, isNot(contains('_generateProgressAnalysis')));
    expect(initStateBody, isNot(contains('_loadProgressAnalysis')));
  });

  test(
      'D-089: a server-side entitlement refusal (EntitlementRequiredException) '
      'is caught explicitly on both AI actions and sent to the paywall, not '
      'left to fall into the generic catch-all — regression test for a '
      'defect found live: this screen\'s local entitlement cache said '
      '"trialing" while Firestore\'s own record disagreed, so the '
      'client-side gate passed and the backend correctly refused with 402, '
      'but the screen showed a dead-end "please try again" for a condition '
      'retrying can never fix', () {
    final source = File('lib/screens/profile.dart').readAsStringSync();
    expect(source, contains('on EntitlementRequiredException'));
    expect(source, contains('_handleEntitlementRefusal'));
    expect(source, contains('pullFromServer'));
  });

  group(
      'D-138 / D-138-AC-04: the profile screen exposes only first name and '
      'uses '
      'the app\'s standard rotating background', () {
    final source = File('lib/screens/profile.dart').readAsStringSync();

    test(
        'D-138-AC-01: the background is CrossfadingStockImages — the same rotating '
        '20-photo treatment every other onboarding-family screen uses, '
        'replacing this screen\'s own former private 4-image rotation', () {
      expect(source, contains('CrossfadingStockImages()'));
      expect(source, isNot(contains('backdropImages')));
    });

    test(
        'D-138-AC-03: first name is editable, while provider contact fields and personal '
        'photographs are absent from the profile page', () {
      expect(source, contains('controller: _nameController'));
      expect(source, isNot(contains('_emailController')));
      expect(source, isNot(contains('_phoneController')));
      expect(source, isNot(contains('_pickPhoto')));
      expect(source, isNot(contains('_photoAvatar')));
      expect(source, isNot(contains('Add photo')));
      expect(source, isNot(contains('Change photo')));
      expect(source, isNot(contains('Remove')));
    });

    test('D-141-AC-01/D-141-AC-02: only first name persists through the profile Save action', () {
      expect(source, contains('controller: _nameController'));
      expect(source, isNot(contains('Future<void> _saveFirstName')));
      expect(source, isNot(contains('Future<void> _saveEmail')));
      expect(source, isNot(contains('Future<void> _savePhone')));
      final saveStart = source.indexOf('Future<void> _saveProfileInfo');
      final saveEnd = source.indexOf('\n  }', saveStart);
      final saveBody = source.substring(saveStart, saveEnd);
      expect(saveBody, contains('_db.setFirstName'));
      expect(saveBody, isNot(contains('_db.setEmail')));
      expect(saveBody, isNot(contains('_db.setPhone')));
    });

    test('D-138-AC-04/D-141-AC-03: nothing personal besides first name is described as profile-editable',
        () {
      expect(source, contains('Your first name is saved to your account'));
      expect(source, isNot(contains('Your first name, email, and phone')));
      expect(source, isNot(contains('stays on this device only')));
    });
  });
}
