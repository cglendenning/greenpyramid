import 'package:flutter/material.dart';

class MindsetSelect extends StatefulWidget {
  final List<String> categories;

  const MindsetSelect({
    Key? key,
    required this.categories,
  }) : super(key: key);

  @override
  State<MindsetSelect> createState() => _MindsetSelectState();
}

class _MindsetSelectState extends State<MindsetSelect> {
  static const List<String> moodChoices = [
    'ambitious',
    'anxious',
    'at peace',
    'bored',
    'burned out',
    'defeated',
    'discouraged',
    'doubtful',
    'fearful',
    'frustrated',
    'inadequate',
    'lacking skills',
    'inspired',
    'like an imposter',
    'motivated',
    'nervous',
    'overwhelmed',
    'pessimistic',
    'proud of my achievements',
    'regretful',
    'self-conscious',
    'settled',
    'stressed',
    'stuck',
    'thwarted',
    'unmotivated',
    'vibrant',
    'worried',
  ];

  String? selectedMood;
  String? selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Mindset'),
        backgroundColor: const Color(0xFF66CC5D),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Mindset matters! The way you feel about different areas of your life can shape your actions and your results. Take a moment to reflect on your current mindset, then choose the area you want to focus on. This helps your coach give you the most relevant support.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            const Text('How are you feeling today?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedMood,
              hint: const Text('Select a mindset...'),
              items: moodChoices
                  .map((mood) => DropdownMenuItem(
                        value: mood,
                        child: Text(mood),
                      ))
                  .toList(),
              onChanged: (mood) {
                setState(() {
                  selectedMood = mood;
                  selectedCategory = null;
                });
              },
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            if (selectedMood != null) ...[
              const SizedBox(height: 32),
              const Text('Which area of your life?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                hint: const Text('Select a category...'),
                items: widget.categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (cat) {
                  setState(() {
                    selectedCategory = cat;
                  });
                  if (selectedMood != null && cat != null) {
                    Navigator.pop(context, [selectedMood, cat]);
                  }
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
