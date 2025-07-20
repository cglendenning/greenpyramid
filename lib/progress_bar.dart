import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final double barHeight;
  final double pillWidth;
  final double pillHeight;
  final Color color;

  const ProgressBar({
    Key? key,
    required this.currentStep,
    required this.totalSteps,
    this.barHeight = 6.0,
    this.pillWidth = 12.0,
    this.pillHeight = 6.0,
    this.color = const Color(0xFF66CC5D),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double progress = currentStep / totalSteps;
    final double barWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      height: barHeight,
      width: double.infinity,
      child: Stack(
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: barHeight,
            color: color,
            backgroundColor: color.withOpacity(0.2),
          ),
          Positioned(
            left: (barWidth - pillWidth) * progress,
            top: 0,
            child: Container(
              width: pillWidth,
              height: pillHeight,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(3.0)),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 