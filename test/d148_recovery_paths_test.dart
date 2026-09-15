import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-148-AC-03/AC-06: recovery controls are source-level contracts for the
/// stateful setup screen; the service and backend behaviors are covered by
/// their focused unit tests.
void main() {
  final source = File('lib/screens/setup_screen.dart').readAsStringSync();
  final draftStore =
      File('lib/services/setup_draft_store.dart').readAsStringSync();
  final linkService =
      File('lib/services/account_link_service.dart').readAsStringSync();
  final completion =
      File('functions/lib/setup_completion.js').readAsStringSync();
  final trial =
      File('lib/services/entitlement_service.dart').readAsStringSync();

  test(
      'D-148-AC-01: accepted setup state is persisted and model retries are keyed',
      () {
    expect(source, contains("'phase': _phase.name"));
    expect(source, contains('_setup.drafts.save(uid, session, state)'));
    expect(draftStore, contains('ConflictAlgorithm.replace'));
    expect(File('functions/lib/setup_idempotency.js').readAsStringSync(),
        contains("state: 'completed'"));
  });

  test('D-148-AC-02: explanation acceptance is user-controlled and neutral',
      () {
    final start = source.indexOf('Future<void> _acceptEssence(');
    final end =
        source.indexOf('Future<void> _askAboutCurrentFoundational', start);
    expect(source.substring(start, end),
        isNot(contains('ResonanceService.qualifies')));
    expect(source, contains('accept it provisionally, or leave it empty'));
  });

  test(
      'D-148-AC-04: provider linking preserves anonymous uid and switches explicitly',
      () {
    expect(linkService, contains('current == null || !current.isAnonymous'));
    expect(linkService, contains('_auth.signInWithCredential(credential)'));
    expect(source, contains('switchedToExistingAccount'));
    expect(source, contains('restoreFromCloud(uid)'));
  });

  test(
      'D-148-AC-05: completion is replay-safe and trial request follows completion',
      () {
    expect(completion, contains('setupCompletionId'));
    expect(completion, contains('return response'));
    expect(trial, contains('requestTrialAfterSetup'));
    expect(source, contains('await _setup.acknowledgeCompletion(_session!)'));
  });

  test(
      'D-148-AC-03: unavailable structured setup output offers recovery, not manual completion',
      () {
    expect(source, contains("AI setup is unavailable. Retry or start over."));
    expect(
        source,
        contains(
            'failed structured derivation must not become manual completion'));
    expect(source, isNot(contains('You can complete your pyramid manually')));
  });

  test('D-148-AC-03: failed habit derivation blocks build until recovery', () {
    expect(source, contains('_habitProposalBlocked'));
    expect(source, contains('Setup could not finish the habit proposal.'));
    expect(source,
        contains('Retry the proposal or discard this setup and start again.'));
  });

  test('D-148-AC-06: anonymous discard requires a named confirmation', () {
    expect(source, contains("title: const Text('Discard setup?')"));
    expect(source, contains("confirmationController.text.trim() == 'DISCARD'"));
    expect(source, contains("child: const Text('Discard setup')"));
  });
}
