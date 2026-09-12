import 'package:flutter/material.dart';
import 'package:life_ops/widgets/navbar.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// D-160: rewritten to match the app as it's actually built today, not the
/// pre-Council, pre-accounts, pre-Newsfeed version it originally shipped
/// for. Found stale during a direct read-through: "Coach" was retired for
/// the Council of Advisors (D-069); setup described a manual multi-step
/// wizard with day-of-week scheduling, but setup is now a conversation
/// with Mira and day-of-week scheduling moved out of it entirely (D-054);
/// the color legend was missing blue (no tasks defined) and stated 3
/// bands instead of the real 4-band scale (pyramid_stack.dart's
/// setColor); nothing mentioned accounts, the trial/subscription model,
/// the Newsfeed, or the Philosophy screen, none of which existed when
/// this file was first written. Every answer below is checked directly
/// against the current source, not assumed from the old copy.
class FAQ extends StatefulWidget {
  const FAQ({super.key});

  @override
  State<FAQ> createState() => _FAQState();
}

class _FAQState extends State<FAQ> {
  final List<FAQItem> faqItems = [
    FAQItem(
      question: "What is Green Pyramid?",
      answer:
          "Green Pyramid is a values-alignment app built around one idea: some of your habits matter more than others, and the app should treat them that way. During setup you work with Mira, part of Green Pyramid's AI-driven Council of Advisors, to define six personal values — think of them as the six categories in your pyramid. Just like a real pyramid, the values at the base carry more structural weight than the ones near the top: if the foundation weakens, everything above it is at risk.",
    ),
    FAQItem(
      question: "How does the pyramid structure work?",
      answer:
          "Your six values are arranged in three tiers. The three at the base are your foundational values — the bedrock everything else is built on. The two above them are your essential values. The single value at the top is your peak value. Each tier depends on the one below it holding steady, which is why Green Pyramid weighs a missed habit differently depending on which tier it belongs to: a gap in a foundational value carries more weight than the same gap in your peak value.",
    ),
    FAQItem(
      question: "What do the colors mean?",
      answer:
          "• Green: you're consistently completing the habits in that category (roughly 80% or higher)\n• Yellow: you're completing some of them, but there's real room to close the gap (roughly 55–80%)\n• Red: few or none of the habits in that category are being completed (below 55%)\n• Blue: that category doesn't have any habits defined yet\n\nThe goal isn't a perfect pyramid every single day — it's keeping the foundational tier as green as possible, since that's where a gap costs the most.",
    ),
    FAQItem(
      question: "How do I set up my Green Pyramid?",
      answer:
          "Setup is a conversation, not a form. You'll talk with Mira, who asks about your life and, once she has enough to work with, proposes your six values, their tiers, and a starting set of habits for each one. You review and confirm before anything is saved — nothing locks in without your say-so. Categories, habits, and their schedules can all be changed afterward.",
    ),
    FAQItem(
      question: "Do I need an account?",
      answer:
          "Yes. Green Pyramid asks you to sign in with a real Apple or Google account right before your pyramid is first revealed, so your progress is backed up and can be restored if you switch devices or reinstall. You can sign out at any time from this menu, and sign back in — or start over — from the first screen.",
    ),
    FAQItem(
      question: "What are daily actions and why are they important?",
      answer:
          "Each value only becomes real through the specific habits you attach to it. These are the behaviors defined for each category — daily by default, though you control how often — not generic tasks, but the actions that actually move that value from an idea into something you're living. Every time you complete one, you're proving to yourself that you're the kind of person who lives in alignment with what you say matters.",
    ),
    FAQItem(
      question: "How do I track my progress?",
      answer:
          "Tap any category on your pyramid to open that category's day view — a calendar to pick a date and a checklist of that day's habits. Mark each one done or not, and your pyramid's color updates to reflect it. You'll also get up to three notifications a day, in your own local time, nudging you to check in — and if you've given a habit a specific scheduled time, you'll get a reminder just before it, plus a single check-in once the day's scheduled habits have all passed.",
    ),
    FAQItem(
      question: "Can I edit my categories and tasks?",
      answer:
          "Yes. From the bottom navigation bar, open the edit tab and tap any category to change its name, description, or essence — it renders the exact same pyramid as your home screen. To change a category's actual habits, tap that category from the home screen to open its day view, then use \"Edit Task List\" to add or remove habits, or \"Schedule Habits\" to give one a recurring time.",
    ),
    FAQItem(
      question: "What if I miss a day or forget to track?",
      answer:
          "Don't worry — you can always go back and mark tasks complete for a previous date from that category's day view. Green Pyramid tracks completion as a rolling percentage, so an occasional missed day won't drastically move your pyramid's colors. If a scheduled habit's check-in catches you having missed it, you can optionally record a short voice note explaining why — entirely optional, never required.",
    ),
    FAQItem(
      question: "How often should I check my pyramid?",
      answer:
          "You'll receive up to three notifications a day, timed to your local time zone — tailored to your own data while you're on trial or subscribed, and more generic once your trial lapses. Beyond that, checking daily is the surest way to keep your pyramid's colors accurate, but Green Pyramid tracks completion over time, so an occasional missed day won't distort the bigger picture.",
    ),
    FAQItem(
      question: "What is the Council of Advisors?",
      answer:
          "The Council of Advisors is Green Pyramid's AI-driven feature for deeper reflection — a small group of advisors, each with a distinct perspective, that you can talk to any time from this menu. Unlike the pyramid's tracking, the Council is grounded in your actual data: your categories, your essences, your recent progress. It's available during your trial and to subscribers; conversations with it aren't a substitute for professional advice (see Terms and Conditions).",
    ),
    FAQItem(
      question: "What happens after my free trial ends?",
      answer:
          "You get 3 days of full access to everything, no card required. If you subscribe, you keep full access — tailored notifications, the Council of Advisors, and daily AI-written newsfeed articles. If you don't, your pyramid keeps tracking exactly as before, for free, indefinitely — you just lose the AI-driven features, and your notifications become generic reminders instead of tailored ones.",
    ),
    FAQItem(
      question: "What is my Newsfeed?",
      answer:
          "Your Newsfeed is a personal feed generated entirely from your own on-device data — streak milestones, moments where you redefined what a value means to you, and, for trial and subscribed accounts, one AI-written analysis a day of the trends in your pyramid. It's reachable from this menu, and tapping a milestone notification takes you straight to it.",
    ),
    FAQItem(
      question: "How do I know if I'm making progress?",
      answer:
          "Watch your pyramid's colors shift toward green as you stay consistent. The Visualizations tab (the chart icon in the bottom navigation bar) shows detailed trends across all six categories, and your Newsfeed surfaces milestones automatically — streaks, redefined essences, and, once subscribed, a written analysis of what's actually trending in your data.",
    ),
    FAQItem(
      question: "What makes Green Pyramid different from other habit trackers?",
      answer:
          "Most habit trackers treat every habit as interchangeable. Green Pyramid doesn't — it's built around the idea that some values are more foundational to your life than others, and it weighs your behavior accordingly. The Council of Advisors gives you a real conversation grounded in your own data, not a generic tip feed, and the pyramid itself makes your life's balance visible at a glance.",
    ),
    FAQItem(
      question: "How do I get the most out of Green Pyramid?",
      answer:
          "1. Give real thought to your six values and habits during setup — the more honest they are, the more useful everything downstream becomes\n2. Check your pyramid daily and be honest about what you actually completed\n3. Pay special attention to your foundational tier — gaps there cost the most\n4. Talk to the Council of Advisors when you want a real conversation, not just a status check\n5. Check Visualizations and your Newsfeed periodically to see the trends, not just today's snapshot\n6. Edit your categories and habits as your life changes — the pyramid should track you, not the other way around",
    ),
    FAQItem(
      question: "Where can I learn more about Green Pyramid's philosophy?",
      answer:
          "The Philosophy screen, also in this menu, lays out the full thinking behind the pyramid — why values are weighted unequally, what the tiers actually represent, and the idea (borrowed from Simon Sinek) that living in alignment with your values is an infinite game, not something you ever finish.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    analytics.logEvent(name: 'faq_screen');

    return SafeArea(
      child: Scaffold(
        appBar: const NavBar(),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20.0),
              child: const Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Exo2',
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: faqItems.length,
                itemBuilder: (context, index) {
                  return FAQExpansionTile(faqItem: faqItems[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}

class FAQExpansionTile extends StatefulWidget {
  final FAQItem faqItem;

  const FAQExpansionTile({super.key, required this.faqItem});

  @override
  State<FAQExpansionTile> createState() => _FAQExpansionTileState();
}

class _FAQExpansionTileState extends State<FAQExpansionTile> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ExpansionTile(
        title: Text(
          widget.faqItem.question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Exo2',
            // The app runs in dark mode, so the question sat as near-black
            // text on a dark card and was invisible; use the same light
            // primary text color the answer already uses.
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
            child: Text(
              widget.faqItem.answer,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Exo2',
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
