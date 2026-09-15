import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/widgets/pyramid_stack.dart';

/// Characterization tests for the pyramid's block coloring.
///
/// These pin the behavior D-024's restructure (R2) must preserve, and enforce
/// D-017: tiered weighting changes nothing the user sees, so block color must
/// not move.
///
/// II-B records that despite eight `if` branches, `setColor` is effectively a
/// four-band scale. These tests assert that as the actual contract.
void main() {
  const blue = Color(0xFF54B6FF);
  const red = Color(0xFFF96E6E);
  const yellow = Color(0xFFFFE177);
  const green = Color(0xFF66CC5D);

  group('D-017: setColor is a four-band scale', () {
    test('D-017: a category with no tasks defined at all is blue', () {
      expect(setColor(-1), blue);
    });

    test('D-143: a category with tasks defined but none due in the '
        'current window is green, not blue — owner: "whenever there is '
        'a category that has no tasks for that day, the default for the '
        'block should be green"', () {
      expect(setColor(-2), green);
    });

    test('D-017: 0 through 54 is red', () {
      for (final pct in [0, 14, 15, 29, 30, 41, 42, 54]) {
        expect(setColor(pct), red, reason: 'pct=$pct should be red');
      }
    });

    test('D-017: 55 through 79 is yellow', () {
      for (final pct in [55, 66, 67, 79]) {
        expect(setColor(pct), yellow, reason: 'pct=$pct should be yellow');
      }
    });

    test('D-017: 80 through 100 is green', () {
      for (final pct in [80, 89, 90, 100]) {
        expect(setColor(pct), green, reason: 'pct=$pct should be green');
      }
    });

    test('D-017: out-of-range values fall back to blue', () {
      expect(setColor(101), blue);
    });

    test('D-017/D-143: exactly four distinct colors across the whole '
        'range, -2 included', () {
      final distinct = <Color>{};
      for (var pct = -2; pct <= 101; pct++) {
        distinct.add(setColor(pct));
      }
      expect(distinct.length, 4,
          reason: 'II-B records four bands, not the eight the branches imply');
    });

    test('D-017: band boundaries are exactly where II-B says', () {
      expect(setColor(54), red);
      expect(setColor(55), yellow);
      expect(setColor(79), yellow);
      expect(setColor(80), green);
    });
  });

  group('buildColor', () {
    test('D-017: parses a hex string to an opaque color', () {
      expect(buildColor('#66CC5D'), green);
      expect(buildColor('#000000'), const Color(0xFF000000));
    });
  });
}
