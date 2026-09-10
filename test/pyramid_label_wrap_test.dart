import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/widgets/pyramid_painting.dart';

/// D-126: category labels wrap at word boundaries only — never inside a
/// word, no hyphenation — and every line of a given label shares one
/// font size, never a bigger size for a short line just because it has
/// room. Found live twice: first a fixed single-line shrink either went
/// illegibly tiny or overflowed; then Flutter's own multi-line
/// TextPainter, used naively, broke *inside* long words whenever one
/// didn't fit the width on its own. `wrapWords`/`fitWrappedLabel`
/// implement the actual algorithm this calls for directly, so it's
/// tested here rather than trusted to a general-purpose text layout.
///
/// Widths below are derived from `measureLabelWidth` rather than
/// hand-guessed pixel numbers — the test environment's active font can
/// differ from the real app's (Exo2), so a guessed pixel budget would
/// silently test nothing meaningful; measuring through the same code
/// path the algorithm itself uses keeps these scenarios exact regardless
/// of which font is actually active.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fontSize = 20.0;
  final squaringWidth =
      PyramidPainting.measureLabelWidth('Squaring', fontSize);
  final awayWidth = PyramidPainting.measureLabelWidth('Away', fontSize);
  final combinedWidth =
      PyramidPainting.measureLabelWidth('Squaring Away', fontSize);

  group('D-126: wrapWords — greedy word-boundary wrapping', () {
    test('a single word that fits stays on one line', () {
      final lines = PyramidPainting.wrapWords(
          ['Squaring'], squaringWidth + 1, fontSize);
      expect(lines, ['Squaring']);
    });

    test('two words that together fit stay on one line', () {
      final lines = PyramidPainting.wrapWords(
          ['Squaring', 'Away'], combinedWidth + 1, fontSize);
      expect(lines, ['Squaring Away']);
    });

    test('wraps to a new line only at a word boundary, never inside a '
        'word — a width that fits the longer word alone but not both '
        'words combined produces exactly two whole-word lines, never a '
        'hyphenated fragment', () {
      // Wide enough for "Squaring" alone, too narrow for "Squaring Away"
      // combined — exactly the boundary case that matters here.
      final maxWidth = (squaringWidth + combinedWidth) / 2;
      expect(maxWidth, greaterThan(squaringWidth));
      expect(maxWidth, lessThan(combinedWidth));

      final lines = PyramidPainting.wrapWords(
          ['Squaring', 'Away'], maxWidth, fontSize);
      expect(lines, ['Squaring', 'Away']);
      for (final line in lines!) {
        expect(line, isNot(contains('-')));
      }
    });

    test('a single word too long to fit even alone returns null — the '
        'signal to shrink the font size and re-wrap, never to split the '
        'word itself', () {
      final lines = PyramidPainting.wrapWords(
          ['Squaring'], squaringWidth - 1, fontSize);
      expect(lines, isNull);
    });

    test('a too-long word later in a multi-word label returns null too, '
        'even though the earlier word alone would have fit', () {
      final lines = PyramidPainting.wrapWords(
          ['Away', 'Squaring'], awayWidth + 2, fontSize);
      expect(lines, isNull);
    });

    test('an empty word list produces an empty result, not a crash', () {
      expect(PyramidPainting.wrapWords([], 200, fontSize), isEmpty);
    });
  });

  group('D-126: fitWrappedLabel — shrinks only as far as fitting '
      'requires, and applies one size to the whole label', () {
    test('a label that already fits at the starting size keeps that '
        'size, unshrunk', () {
      final (size, lines) = PyramidPainting.fitWrappedLabel(
          'Squaring', squaringWidth + 5, 1000, fontSize);
      expect(size, fontSize);
      expect(lines, ['Squaring']);
    });

    test('a word too wide for the box shrinks the font size until it '
        'fits — wrapping can\'t help a single word, so size is the only '
        'lever available', () {
      final (size, lines) = PyramidPainting.fitWrappedLabel(
          'Squaring', squaringWidth * 0.5, 1000, fontSize);
      expect(size, lessThan(fontSize));
      expect(lines, ['Squaring']);
      // The chosen size must actually make it fit, at the real measured
      // width for that size — not just be smaller than the start.
      expect(PyramidPainting.measureLabelWidth('Squaring', size),
          lessThanOrEqualTo(squaringWidth * 0.5));
    });

    test('two words that don\'t fit combined, but each fit alone, wrap '
        'to two lines at the SAME font size the starting size already '
        'allowed — the short second line is never rendered larger just '
        'because it has room, which is the exact defect this directive '
        'exists to prevent', () {
      final maxWidth = (squaringWidth + combinedWidth) / 2;
      final (size, lines) = PyramidPainting.fitWrappedLabel(
          'Squaring Away', maxWidth, 1000, fontSize);
      expect(size, fontSize, reason: 'both words already fit at the '
          'starting size once wrapped — no shrink was needed at all');
      expect(lines, ['Squaring', 'Away']);
    });

    test('a genuinely tight box shrinks the label\'s font size and keeps '
        'both wrapped lines at that one shared size', () {
      final maxWidth = squaringWidth * 0.6;
      final (size, lines) = PyramidPainting.fitWrappedLabel(
          'Squaring Away', maxWidth, 1000, fontSize);
      expect(size, lessThan(fontSize));
      expect(lines.length, 2);
      // Re-running wrapWords at the returned size, for the SAME width,
      // must reproduce exactly the lines fitWrappedLabel already chose —
      // confirming one size really does govern the whole label, not a
      // per-line decision.
      expect(
          PyramidPainting.wrapWords(['Squaring', 'Away'], maxWidth, size),
          lines);
    });

    test('an empty label produces no lines rather than throwing', () {
      final (_, lines) =
          PyramidPainting.fitWrappedLabel('', 200, 100, fontSize);
      expect(lines, isEmpty);
    });
  });
}
