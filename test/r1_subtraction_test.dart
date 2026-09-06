import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Absence tests for R1's deletions.
///
/// D-079 requires that pure-deletion directives be verified by a test
/// asserting absence. These are the regression guard preventing advertising
/// or the ad-funded ledger from quietly returning.
void main() {
  String read(String path) => File(path).readAsStringSync();

  Iterable<File> dartSources(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  group('D-011: advertising is removed, not disabled', () {
    test('D-011: the ad service and pacer no longer exist', () {
      expect(File('lib/services/ad_service.dart').existsSync(), isFalse);
      expect(File('lib/services/ad_pacer.dart').existsSync(), isFalse);
    });

    test('D-011: no ad SDK dependency remains in pubspec', () {
      expect(read('pubspec.yaml').contains('google_mobile_ads'), isFalse);
    });

    test('D-011: no source file references advertising', () {
      final offenders = <String>[];
      for (final f in dartSources('lib')) {
        final body = f.readAsStringSync().toLowerCase();
        if (body.contains('admob') ||
            body.contains('google_mobile_ads') ||
            body.contains('adservice') ||
            body.contains('interstitialpacer')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'advertising must be deleted, not disabled');
    });

    test('D-011: no ad keys remain in the platform manifests', () {
      expect(read('android/app/src/main/AndroidManifest.xml').toLowerCase()
          .contains('admob'), isFalse);
      expect(read('ios/Runner/Info.plist').toLowerCase()
          .contains('admob'), isFalse);
    });
  });

  group('D-018: the usage ledger is deleted', () {
    test('D-018: usage_ledger.dart no longer exists', () {
      expect(File('lib/services/usage_ledger.dart').existsSync(), isFalse);
    });

    test('D-018: no source file references the ledger', () {
      final offenders = <String>[];
      for (final f in dartSources('lib')) {
        if (f.readAsStringSync().contains('UsageLedger')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty);
    });

    test('D-018: AiGuard cannot block a call for lack of balance', () {
      final guard = read('lib/services/ai_guard.dart');
      expect(guard.contains('costMicros'), isFalse);
      expect(guard.contains('tryDebit'), isFalse);
    });

    test('D-018: AiGuard keeps its rate limits and sanitation', () {
      final guard = read('lib/services/ai_guard.dart');
      expect(guard.contains('maxCallsPerMinute'), isTrue);
      expect(guard.contains('maxCallsPerDay'), isTrue);
      expect(guard.contains('sanitizeField'), isTrue);
      expect(guard.contains('untrustedDataNotice'), isTrue);
    });
  });

  group('R1: dead code removed', () {
    test('D-019: the dead setColorAndShade is gone', () {
      // Located by search rather than a fixed path, so the layered restructure
      // (D-024) and any later move cannot silently neuter this assertion.
      final offenders = dartSources('lib')
          .where((f) => f.readAsStringSync().contains('setColorAndShade'))
          .map((f) => f.path)
          .toList();
      expect(offenders, isEmpty);
    });

    test('R1: lib/graveyard is deleted', () {
      expect(Directory('lib/graveyard').existsSync(), isFalse);
    });
  });
}
