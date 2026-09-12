import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-028: a Council session scoped to one category. CouncilScreen owns
/// live service singletons (CouncilService.instance) the same way
/// GeneralCouncilScreen and SetupScreen do, so — same as those — this is a
/// source-structure test, not a widget test (see
/// general_council_screen_test.dart's own comment on this class of screen).
void main() {
  group('D-148: the transcript scrolls to the latest message automatically '
      '— found live: "the screen does not scroll automatically down to the '
      'bottom to show the latest response so the response is sitting there '
      'below the visible screen"', () {
    final source = File('lib/screens/council_screen.dart').readAsStringSync();

    test('a ScrollController is created, disposed, and passed to '
        'CouncilTranscript', () {
      expect(source, contains('final _scrollController = ScrollController();'));
      expect(source, contains('_scrollController.dispose();'));
      expect(source, contains('scrollController: _scrollController,'));
    });

    test('_scrollToBottom animates to maxScrollExtent after a frame, and is '
        'called whenever the session (messages or typing indicator) changes',
        () {
      expect(source, contains('void _scrollToBottom()'));
      expect(source, contains('addPostFrameCallback'));
      expect(source, contains('_scrollController.position.maxScrollExtent'));
      expect(
          '_scrollToBottom();'.allMatches(source).length, greaterThanOrEqualTo(2));
    });
  });
}
