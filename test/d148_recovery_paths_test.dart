import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-148-AC-03/AC-06: recovery controls are source-level contracts for the
/// stateful setup screen; the service and backend behaviors are covered by
/// their focused unit tests.
void main() {
  final source = File('lib/screens/setup_screen.dart').readAsStringSync();

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
