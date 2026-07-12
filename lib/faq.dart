import 'package:flutter/material.dart';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

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
          "Green Pyramid is an AI-empowered system designed to make it effortless to live your best possible life. It's based on the principle that foundational habits have exponentially greater impact on your life than non-foundational ones. Think of it like a real pyramid - if the foundation is weak, the whole structure crumbles. The same applies to your life.",
    ),
    FAQItem(
      question: "How does the pyramid structure work?",
      answer:
          "The pyramid has 6 levels, with the most important values at the bottom (foundational) and less critical ones at the top. Categories 1, 2, and 3 are your foundational values - these are the bedrock of life success and well-being. Any gaps in these foundational habits carry significantly more weight than gaps in higher categories.",
    ),
    FAQItem(
      question: "What do the colors mean?",
      answer:
          "• Green: You're crushing most or all of your habits toward your best life\n• Yellow: You're executing some of your habits toward your best life\n• Red: You're doing few or none of your habits toward your best life\n\nThe goal is to keep your pyramid as green as possible, especially the foundational levels.",
    ),
    FAQItem(
      question: "How do I set up my Green Pyramid?",
      answer:
          "1. Choose your 6 most important life values/categories\n2. For each category, define specific daily tasks or habits\n3. Set which days of the week each task should be completed\n4. Complete the setup process to start tracking your progress\n\nYou can always edit your categories and tasks later through the menu.",
    ),
    FAQItem(
      question: "What are daily actions and why are they important?",
      answer:
          "Each of your values requires daily action if you're truly committed to that value. Daily actions are the specific habits and tasks you've defined for each category. These aren't just random tasks - they're carefully chosen actions that align with your core values and move you toward your best life.",
    ),
    FAQItem(
      question: "How do I track my progress?",
      answer:
          "Every day you'll receive notifications (morning, afternoon, evening) to check in on your tasks from the previous day. Simply tap on each category in your pyramid to mark tasks as completed or not completed. Your pyramid colors will update based on your completion percentage for each category.",
    ),
    FAQItem(
      question: "What is the Coach feature?",
      answer:
          "The Coach is an AI-powered life coach that analyzes your habit tracking data and provides personalized insights. It prioritizes foundational habit gaps while acknowledging progress in all areas. The coach offers specific, actionable guidance to help you improve your habit execution and overall life balance.",
    ),
    FAQItem(
      question: "How often should I check my pyramid?",
      answer:
          "You'll receive 3 notifications per day (9am, 12pm, 8pm) to remind you to check your tasks. It's best to review your previous day's tasks daily to maintain consistency and see your progress trends. The more regularly you track, the more accurate your pyramid colors will be.",
    ),
    FAQItem(
      question: "Can I edit my categories and tasks?",
      answer:
          "Yes! You can edit your categories and tasks at any time. From the home screen, tap the Edit icon in the bottom navigation bar to modify your pyramid categories. You can also tap on any category in the pyramid to edit the specific tasks for that category.",
    ),
    FAQItem(
      question: "What if I miss a day or forget to track?",
      answer:
          "Don't worry! You can always go back and mark tasks as completed for previous days. The system tracks your completion percentage over time, so occasional missed days won't drastically affect your overall progress. The key is consistency over the long term.",
    ),
    FAQItem(
      question: "How do I know if I'm making progress?",
      answer:
          "Watch your pyramid colors! As you become more diligent with your daily tasks, your pyramid will shift from red or yellow to green. You can also use the Progress screen to see detailed statistics and trends over time. The Coach will also provide insights on your progress and areas for improvement.",
    ),
    FAQItem(
      question: "What makes Green Pyramid different from other habit trackers?",
      answer:
          "Green Pyramid focuses on the hierarchical importance of habits, recognizing that foundational habits have exponentially greater impact. It's not just about tracking random tasks - it's about building a solid foundation for your best life. The AI coach provides personalized guidance, and the visual pyramid makes it easy to see your life balance at a glance.",
    ),
    FAQItem(
      question: "How do I get the most out of Green Pyramid?",
      answer:
          "1. Complete the full setup process with meaningful values and tasks\n2. Check your pyramid daily and be honest about task completion\n3. Pay special attention to the foundational categories (bottom 3)\n4. Use the Coach feature for personalized insights\n5. Review your progress regularly to identify patterns\n6. Adjust your tasks and categories as your life evolves",
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
            color: Colors.black87,
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
