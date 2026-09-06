import 'package:flutter/material.dart';

/// D-027/D-029: the four Council advisors, ported from Kansei's
/// `AdvisorConfig` (`goal-executor/lib/widgets/advisor_avatar.dart`).
/// Advisors are stances (feeling / consistency / leverage / principle), not
/// domains — every advisor may probe any domain (D-029). Persona prose is
/// unchanged from Kansei so it stays recognizably itself.
class AdvisorConfig {
  final String key;
  final String name;
  final String title;
  final String trait;
  final String description;
  final Color bubbleColor;
  final Color fallbackColor;
  final String assetPath;

  const AdvisorConfig({
    required this.key,
    required this.name,
    required this.title,
    required this.trait,
    required this.description,
    required this.bubbleColor,
    required this.fallbackColor,
    required this.assetPath,
  });

  static const Map<String, AdvisorConfig> _configs = {
    'mira': AdvisorConfig(
      key: 'mira',
      name: 'Mira',
      title: 'The Heart',
      trait: 'Caring',
      description:
          'Mira notices what\'s beneath the surface. She listens for the emotional undercurrent in every situation — not just what happened, but what it felt like, and what it means. Her counsel comes from a place of deep, unhurried care.',
      bubbleColor: Color(0xFF3A2028),
      fallbackColor: Color(0xFF5A3040),
      assetPath: 'images/advisors/advisor_mira.jpg',
    ),
    'kenji': AdvisorConfig(
      key: 'kenji',
      name: 'Kenji',
      title: 'The Anchor',
      trait: 'Consistent',
      description:
          'Kenji grounds every conversation in what is true and enduring. He notices patterns, holds the long thread, and brings things back to fundamentals when the moment calls for it. His counsel is steady and reliable.',
      bubbleColor: Color(0xFF2D2510),
      fallbackColor: Color(0xFF4A3D18),
      assetPath: 'images/advisors/advisor_kenji.jpg',
    ),
    'noa': AdvisorConfig(
      key: 'noa',
      name: 'Noa',
      title: 'The Edge',
      trait: 'Competent',
      description:
          'Noa identifies leverage. She asks what is most likely to work, finds the next concrete step, and cuts through complexity with strategic precision. Her counsel moves things forward.',
      bubbleColor: Color(0xFF252A20),
      fallbackColor: Color(0xFF3A4530),
      assetPath: 'images/advisors/advisor_noa.jpg',
    ),
    'eli': AdvisorConfig(
      key: 'eli',
      name: 'Eli',
      title: 'The Compass',
      trait: 'Principled',
      description:
          'Eli asks what is right, not just what is effective. He notices when means and ends drift apart, and holds the council — and the work — to a higher standard. His counsel is grounded in character.',
      bubbleColor: Color(0xFF252030),
      fallbackColor: Color(0xFF3A3055),
      assetPath: 'images/advisors/advisor_eli.jpg',
    ),
  };

  static AdvisorConfig forKey(String key) =>
      _configs[key] ?? _configs['mira']!;

  static List<AdvisorConfig> get all => _configs.values.toList();

  static const List<String> orderedKeys = ['mira', 'kenji', 'noa', 'eli'];
}
