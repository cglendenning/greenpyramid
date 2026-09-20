import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Settings surface exposes the public privacy policy', () {
    final settings = File('lib/screens/settings.dart').readAsStringSync();
    expect(settings,
        contains('https://greenpyramid-privacy.cglendenning.chatgpt.site'));
    expect(settings, contains("Text('Privacy Policy')"));
  });

  test('store account deletion is authenticated, confirmed and server-owned',
      () {
    final functions = File('functions/index.js').readAsStringSync();
    final route =
        functions.substring(functions.indexOf("app.post('/deleteAccount'"));
    expect(route, contains('requireFirebaseAuth'));
    expect(route, contains('req.body?.confirm !== true'));
    expect(route, contains('req.uid'));
    expect(route, contains('deleteAccountTree'));
    expect(route, isNot(contains('req.body?.uid')));
  });

  test('client deletion erases local content only after the server succeeds',
      () {
    final service =
        File('lib/services/account_deletion_service.dart').readAsStringSync();
    expect(service, contains(r"Uri.parse('$_baseUrl/deleteAccount')"));
    expect(service, contains("body: jsonEncode({'confirm': true})"));
    expect(service, contains('clearLocalDataForAccountDeletion'));
    expect(service, contains('cancelAllPendingNotifications'));
    expect(service, contains('_auth.signOut()'));

    final settings = File('lib/screens/settings.dart').readAsStringSync();
    expect(settings, contains('Delete account'));
    expect(settings, contains('Delete permanently'));
    expect(
        settings, contains('AccountDeletionService.instance.deleteAccount()'));
  });

  test('local deletion includes user data, setup drafts and demo residue', () {
    final db = File('lib/services/db.dart').readAsStringSync();
    final methodStart = db.indexOf('clearLocalDataForAccountDeletion');
    final methodEnd = db.indexOf('\n  }', methodStart);
    final method = db.substring(methodStart, methodEnd);
    for (final table in [
      'taskLogTable',
      'taskTable',
      'categoryEssenceTable',
      'categoryTable',
      'newsfeedItemTable',
      'demoTaskTable',
      "'setup_drafts'",
    ]) {
      expect(method, contains(table));
    }
  });
}
