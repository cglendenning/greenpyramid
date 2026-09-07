import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-051/D-052: category and habit names returned by the Council backend
/// must be checked with `looksLikePlaceholder` (model_output_guard_test.dart
/// covers its actual logic) before ever reaching the screen. Structural,
/// since CouncilClient's real HTTP path isn't unit-testable without a live
/// backend or a seam this class doesn't have (see its own doc comment:
/// tests fake it by overriding public methods, not the private transport).
void main() {
  test(
      'deriveCategories and deriveHabits both call the placeholder guard '
      'before returning — regression test for a defect found live: a '
      'literal "<UNKNOWN>" category name reached the setup screen '
      'unvalidated', () {
    final source =
        File('lib/services/council_client.dart').readAsStringSync();

    final categoriesStart = source.indexOf('Future<List<CategoryProposal>> deriveCategories(');
    final habitsStart = source.indexOf('Future<List<String>> deriveHabits(');
    expect(categoriesStart, greaterThan(-1));
    expect(habitsStart, greaterThan(categoriesStart));

    final domainFindingsStart =
        source.indexOf('deriveDomainFindings(', habitsStart);
    final categoriesBody = source.substring(categoriesStart, habitsStart);
    final habitsBody = domainFindingsStart > habitsStart
        ? source.substring(habitsStart, domainFindingsStart)
        : source.substring(habitsStart);

    expect(categoriesBody, contains('looksLikePlaceholder'));
    expect(habitsBody, contains('looksLikePlaceholder'));
  });

  test(
      'D-051: CategoryProposal carries a description, and deriveCategories '
      'parses it and guards it the same way it guards the name — a short '
      'resonant line, not a bare label, was the owner\'s explicit ask '
      'after seeing verbose one-word-only category names live', () {
    final modelSource =
        File('lib/services/council_client.dart').readAsStringSync();
    expect(modelSource, contains('final String? description;'));
    expect(modelSource, contains("description: c['description'] as String?"));
    expect(
        modelSource,
        contains(
            "looksLikePlaceholder(c.description!)"));
  });
}
