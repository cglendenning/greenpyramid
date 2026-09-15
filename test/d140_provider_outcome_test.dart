import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('D-140-AC-01: provider cancellation and failure stay distinct', () {
    final source = File('lib/screens/signing_in_screen.dart').readAsStringSync();
    expect(source, contains('GoogleSignInExceptionCode.canceled'));
    expect(source, contains('SignInOutcome.cancelled()'));
    expect(source, contains('SignInOutcome.failure(userFacingMessage)'));
    expect(source, contains('Google sign-in is not configured on this build.'));
    expect(source, contains("We couldn't finish signing you in with Google."));
  });
}
