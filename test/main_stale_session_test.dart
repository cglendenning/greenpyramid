import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-137: structural regression test, not a full widget pump — main()
/// owns Firebase/notification bootstrap end to end, which this suite
/// doesn't mock. Same source-text-assertion pattern
/// schedule_habits_screen_test.dart already uses for its D-128 group.
///
/// Found live: a genuine app delete-and-reinstall still resumed the old
/// Firebase session (iOS Keychain survives app deletion; local SQLite
/// does not), landing on the home screen's D-132 "link your account"
/// gate instead of the true first screen a fresh install should show.
void main() {
  test('D-137: a stale Firebase session survives a delete-and-reinstall '
      '(local storage empty, but Firebase still has a session) — sign it '
      'out before routing, so local reality and Firebase reality agree '
      'again', () {
    final source = File('lib/main.dart').readAsStringSync();

    final staleSessionCheck = source.indexOf(
        'if (defaultCats == 6 && FirebaseAuth.instance.currentUser != null)');
    expect(staleSessionCheck, greaterThan(-1));

    final routingCheck =
        source.indexOf('if (FirebaseAuth.instance.currentUser == null || defaultCats == 6)');
    expect(routingCheck, greaterThan(staleSessionCheck),
        reason: 'the stale-session sign-out must happen before the '
            'routing decision reads currentUser, or it has no effect on '
            'which screen is chosen');

    final between = source.substring(staleSessionCheck, routingCheck);
    expect(between, contains('await AuthService.instance.signOut();'));
  });
}
