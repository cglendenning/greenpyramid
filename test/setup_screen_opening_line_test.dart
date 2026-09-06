import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-067: Mira's opening line is fixed, hand-written copy — not generated.
/// Structural (source-text) test, matching this repo's convention for
/// literal required copy, since SetupScreen itself depends on live
/// singletons (SetupService.instance) the same way CouncilScreen does and
/// isn't widget-tested directly.
void main() {
  test('D-067: the opening line is the exact fixed copy, word for word', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    // The Dart source may wrap the literal across adjacent string
    // concatenation, so compare against source with line-break whitespace
    // collapsed, not the raw file text as one continuous line.
    final flattened = source.replaceAll(RegExp(r'"\s*\n\s*"'), '');
    expect(
      flattened,
      contains("I'm not going to ask what you want to change. Tell me "
          "about a day recently that felt like it mattered."),
    );
  });

  test('D-042: setup carries one action, not a menu — a text field, no '
      'category picker widget', () {
    final source = File('lib/screens/setup_screen.dart').readAsStringSync();
    expect(source, isNot(contains('DropdownButton')));
    expect(source, isNot(contains('preset')));
  });
}
