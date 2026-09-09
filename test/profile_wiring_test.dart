import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-114: profile.dart's vision-statement regeneration and 30-day
/// progress analysis are Claude-backed via ProfileService, gated by
/// D-016's entitlement check like every other non-setup AI surface —
/// structural, matching this repo's convention for screens built on live
/// singletons (setup_screen.dart, editpyramid.dart, tasklist.dart aren't
/// directly widget-tested elsewhere either).
void main() {
  test(
      'D-114: profile.dart no longer imports the legacy OpenAI transport — '
      'regression test for the root cause found live via Cloud Run logs: '
      'this screen was still calling a defunct OpenAI account with zero '
      'credits, the one AI surface D-069/D-083\'s retirement of the legacy '
      'AI screens missed', () {
    final source = File('lib/screens/profile.dart').readAsStringSync();
    expect(source, isNot(contains('ai_proxy_client.dart')));
    expect(source, isNot(contains('AiProxy.instance')));
  });

  test('D-114: profile.dart routes both AI actions through ProfileService',
      () {
    final source = File('lib/screens/profile.dart').readAsStringSync();
    expect(source, contains('ProfileService'));
    expect(source, contains('_profile.regenerateVisionStatement()'));
    expect(source, contains('_profile.generateProgressAnalysis()'));
  });

  test(
      'D-114/D-016: both AI actions are gated by EntitlementService before '
      'the call, routing an unentitled account to the paywall first — the '
      'same pattern every other non-setup AI surface uses', () {
    final source = File('lib/screens/profile.dart').readAsStringSync();
    expect(source, contains('EntitlementService.instance.isEntitled()'));
    expect(source, contains('PaywallScreen('));
    final regenIdx = source.indexOf('_regenerateVisionStatement()');
    final analysisIdx = source.indexOf('_generateProgressAnalysis()');
    final ensureIdx = source.indexOf('_ensureEntitled');
    expect(regenIdx, greaterThan(-1));
    expect(analysisIdx, greaterThan(-1));
    expect(ensureIdx, greaterThan(-1));
  });

  test(
      'D-114: the 30-day progress analysis is an explicit button tap, not '
      'an automatic call fired on screen open — the legacy version fired '
      'two unconditional AI calls in initState() every time this screen '
      'opened, before any entitlement or cost check ran', () {
    final source = File('lib/screens/profile.dart').readAsStringSync();
    final initStateStart = source.indexOf('void initState()');
    final initStateEnd = source.indexOf('\n  }', initStateStart);
    final initStateBody =
        source.substring(initStateStart, initStateEnd == -1 ? source.length : initStateEnd);
    expect(initStateBody, isNot(contains('_generateProgressAnalysis')));
    expect(initStateBody, isNot(contains('_loadProgressAnalysis')));
  });
}
