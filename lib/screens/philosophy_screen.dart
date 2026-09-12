import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/stock_images.dart';

/// D-159: a static, editorial screen explaining the philosophy behind
/// Green Pyramid — reachable from the hamburger menu. Owner supplied the
/// source copy verbatim and asked for it to be expanded into subsections
/// "interwoven" with imagery drawn from the same 20-photo stock pool used
/// elsewhere (`kStockImages`), while keeping the same voice and intent —
/// "I want you to be an expert editor to create a beautiful philosophy
/// page." Every paragraph below expands the owner's own six ideas (the
/// mission, the pyramid's hierarchy, unequal habit weighting, daily
/// practice as proof, the infinite game, and protecting the foundation
/// under chaos) without introducing any new claim about how the app
/// behaves. Purely static: no AI call, no network fetch, no per-user
/// data — the six values it discusses are described in the abstract, not
/// read from the signed-in user's own pyramid.
class PhilosophyScreen extends StatelessWidget {
  const PhilosophyScreen({super.key});

  static final _heroImage = kStockImages[8];
  static final _sectionImages = [
    kStockImages[2],
    kStockImages[15],
    kStockImages[5],
    kStockImages[11],
    kStockImages[18],
  ];

  static const _eyebrowStyle = TextStyle(
    fontFamily: 'Exo2',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.4,
    color: AppColors.brandGreen,
  );

  static const _headingStyle = TextStyle(
    fontFamily: 'Raleway',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static const _bodyStyle = TextStyle(
    fontFamily: 'Raleway',
    fontSize: 15.5,
    color: AppColors.textSecondary,
    height: 1.7,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section(
                    eyebrow: 'THE MISSION',
                    heading: 'What Truly Matters',
                    paragraphs: const [
                      "Green Pyramid exists for one reason: to make it "
                          "effortless to remain aligned with what truly "
                          "matters to you. Not what's urgent. Not what's "
                          "loudest today. What actually matters — the things "
                          "that, if you're honest with yourself, define "
                          "whether a life is well lived.",
                      "We call the things that matter most your values. "
                          "During setup, you named six of them — the six "
                          "categories that make up your pyramid. Everything "
                          "the app does afterward is in service of one "
                          "question: are your daily actions actually pointed "
                          "at these six things, or have they quietly "
                          "drifted?",
                    ],
                  ),
                  _interstitialImage(_sectionImages[0]),
                  _section(
                    eyebrow: 'THE HIERARCHY',
                    heading: 'The Shape of a Life',
                    paragraphs: const [
                      "Your six values don't sit side by side as equals. "
                          "They compete for the same finite hours, and Green "
                          "Pyramid's shape says something true about that "
                          "competition: three values form the base of the "
                          "pyramid, two sit above them, and one occupies the "
                          "peak.",
                      "The three at the base are your foundational values — "
                          "the bedrock everything else is built on. Above "
                          "them, your two essential values. At the top, a "
                          "single peak value. Each layer depends on the "
                          "layer beneath it holding steady, the same way a "
                          "real pyramid would collapse without its base. "
                          "The shape isn't decoration; it's a diagram of how "
                          "a life is actually structured.",
                    ],
                  ),
                  _interstitialImage(_sectionImages[1]),
                  _section(
                    eyebrow: 'THE WEIGHTING',
                    heading: 'Not Every Habit Carries the Same Weight',
                    paragraphs: const [
                      "Because the layers aren't equal, missing a habit "
                          "isn't either. Skip something tied to a "
                          "foundational value and the cost is real — you're "
                          "chipping at the bedrock. Skip something tied to "
                          "your peak value on the same day and, while it "
                          "still matters, it doesn't carry the same weight. "
                          "The foundational values are called foundational "
                          "for a reason.",
                      "Green Pyramid takes this seriously enough to build "
                          "it into how it weighs your behavior. Every habit "
                          "is scored differently depending on which value it "
                          "supports, not treated as one interchangeable "
                          "checkbox among many. The app is built to notice "
                          "which value a habit protects — and to treat a "
                          "missed day accordingly.",
                    ],
                  ),
                  _interstitialImage(_sectionImages[2]),
                  _section(
                    eyebrow: 'THE PRACTICE',
                    heading: 'Proof, Not Promises',
                    paragraphs: const [
                      "Within each value sits a set of behaviors, most of "
                          "them meant to happen daily — though the frequency "
                          "is always yours to set. A value isn't real until "
                          "it shows up as something you actually do, "
                          "repeatedly, on ordinary days when no one's "
                          "watching.",
                      "Every time you execute one of these behaviors, "
                          "you're not just checking a box. You're proving "
                          "something to yourself: that you are, in fact, "
                          "the kind of person who lives in alignment with "
                          "what they say matters. That proof compounds. "
                          "It's the entire point.",
                    ],
                  ),
                  _interstitialImage(_sectionImages[3]),
                  _section(
                    eyebrow: 'THE HORIZON',
                    heading: 'The Infinite Game',
                    paragraphs: const [
                      "Ten years from now, living in alignment with your "
                          "values will matter exactly as much as it does "
                          "today — not more urgent, not less. There's no "
                          "finish line where the game ends and you get to "
                          "stop playing.",
                      "Simon Sinek calls this the infinite game: some games "
                          "are played to win and end; others are played "
                          "simply to keep playing, for as long as possible, "
                          "as well as possible. Green Pyramid is built for "
                          "the second kind. It isn't optimizing for a streak "
                          "that peaks and breaks. It's optimizing for a life "
                          "you can keep living, in alignment, indefinitely.",
                    ],
                  ),
                  _interstitialImage(_sectionImages[4]),
                  _section(
                    eyebrow: 'THE PHILOSOPHY',
                    heading: 'When Life Gets Chaotic',
                    paragraphs: const [
                      "Life will not cooperate with your plans. "
                          "Disruptions happen — a bad week at work, a sick "
                          "kid, a canceled flight — and something has to "
                          "give. Green Pyramid's philosophy is that "
                          "trade-offs between habits are not a failure of "
                          "discipline; they're a fact of being alive.",
                      "What the app can do is make sure the trade-offs "
                          "happen in the right order. When something has to "
                          "give, Green Pyramid biases toward protecting your "
                          "foundational values first — the bedrock stays "
                          "intact even when everything above it gets shaken "
                          "loose. That's the whole idea: not a life with no "
                          "disruptions, but a life that knows what to "
                          "protect when they come.",
                    ],
                  ),
                  const SizedBox(height: 20),
                  _closing(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return SizedBox(
      height: 380,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(_heroImage, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.35),
                  AppColors.background,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GREEN PYRAMID',
                  style: TextStyle(
                    fontFamily: 'Exo2',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.2,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Philosophy',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'A hierarchy for what matters, built to hold under '
                  'pressure.',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String eyebrow,
    required String heading,
    required List<String> paragraphs,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: _eyebrowStyle),
          const SizedBox(height: 8),
          Text(heading, style: _headingStyle),
          const SizedBox(height: 14),
          for (final p in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(p, style: _bodyStyle),
            ),
        ],
      ),
    );
  }

  Widget _interstitialImage(String asset) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Image.asset(asset, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _closing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 36,
          child: Divider(color: AppColors.brandGreen, thickness: 1, height: 1),
        ),
        const SizedBox(height: 20),
        const Text(
          'This is Green Pyramid: a hierarchy for what matters, built to '
          'hold under pressure.',
          style: TextStyle(
            fontFamily: 'Raleway',
            fontStyle: FontStyle.italic,
            fontSize: 17,
            color: AppColors.textPrimary,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
