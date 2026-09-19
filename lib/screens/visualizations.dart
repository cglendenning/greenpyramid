import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:life_ops/services/visualization_service.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/widgets/crossfading_stock_images.dart';

/// A short, local-data-only journey through the user's recent work.
class VisualizationsScreen extends StatefulWidget {
  const VisualizationsScreen({super.key});

  @override
  State<VisualizationsScreen> createState() => _VisualizationsScreenState();
}

class _VisualizationsScreenState extends State<VisualizationsScreen> {
  static const _pageCount = 6;

  final _pageController = PageController();
  late Future<VisualizationData> _future;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _future = VisualizationService.instance.load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_JourneyPageData> _pages(VisualizationData data) {
    final strongest = data.strongest;
    final careArea = data.careArea;
    final rhythmTitle = !data.hasData
        ? 'Your first week is waiting.'
        : data.rhythmIsGrowing
            ? 'Your effort grew as the week went on.'
            : data.rhythmIsHolding
                ? 'You kept your rhythm steady.'
                : 'You found your way back during the week.';

    return [
      _JourneyPageData(
        label: 'START HERE',
        title: data.hasData
            ? 'You kept showing up.'
            : 'Your story is just starting.',
        diagram: _AttemptsDiagram(data: data),
        commentary: data.hasData
            ? '${data.completedAttempts} things got done in the last 30 days. That is real work, and it is already adding up.'
            : 'Your first check-in will give this story its first chapter.',
      ),
      _JourneyPageData(
        label: 'YOUR STRENGTH',
        title: strongest == null
            ? 'Every beginning needs a first step.'
            : '${strongest.name} is leading the way.',
        diagram: _StrongestDiagram(category: strongest),
        commentary: strongest == null
            ? 'Pick one small thing to do today. Small steps make a pattern.'
            : 'You completed ${strongest.roundedRate}% of your ${strongest.name.toLowerCase()} check-ins. This is a strength you can lean on.',
      ),
      _JourneyPageData(
        label: 'THE RHYTHM',
        title: rhythmTitle,
        diagram: _WeekBars(days: data.days),
        commentary: data.hasData
            ? 'Each bar is a day you gave your plan some attention. Your effort is becoming easier to see.'
            : 'The bars will fill in as you make your first week visible.',
      ),
      _JourneyPageData(
        label: 'THE RETURN',
        title: data.activeDays == 1
            ? 'You came back once. That counts.'
            : data.activeDays > 1
                ? 'You came back ${data.activeDays} days.'
                : 'There is always a next day.',
        diagram: _ReturnDots(days: data.days),
        commentary: data.activeDays > 0
            ? 'Progress is not about being perfect. It is about giving yourself another chance to begin.'
            : 'The next check-in is a clean place to begin again.',
      ),
      _JourneyPageData(
        label: 'A GENTLE CLUE',
        title: careArea == null
            ? 'Your next win is waiting.'
            : '${careArea.name} could use a little room.',
        diagram: _CareDiagram(category: careArea),
        commentary: careArea == null
            ? 'There is not enough history for a clue yet. Keep going and one will appear.'
            : 'This is not a judgment. It is a friendly place to try one smaller step.',
      ),
      _JourneyPageData(
        label: 'TAKE THIS WITH YOU',
        title: data.hasData
            ? 'You are building something that lasts.'
            : 'You are ready to build something that lasts.',
        diagram: _CompletionDiagram(data: data),
        commentary: data.hasData
            ? 'You do not need a perfect day. You need the next doable step. You have already proved you can take it.'
            : 'One small action is enough to start. The next page of your story is yours to write.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Opacity(
            opacity: 0.24,
            child: CrossfadingStockImages(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0.78),
                  AppColors.background.withValues(alpha: 0.96),
                ],
              ),
            ),
          ),
          SafeArea(
            child: FutureBuilder<VisualizationData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Your story is taking a moment to load. Please try again.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final pages = _pages(snapshot.data!);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'YOUR JOURNEY',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: AppColors.brandGreen,
                                  letterSpacing: 1.7,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            '${_page + 1} / $_pageCount',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: pages.length,
                        onPageChanged: (page) => setState(() => _page = page),
                        itemBuilder: (context, index) {
                          final page = pages[index];
                          return Semantics(
                            label:
                                'Page ${index + 1} of ${pages.length}: ${page.title}',
                            child: _JourneyPage(data: page),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              pages.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: index == _page ? 24 : 7,
                                height: 7,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: index == _page
                                      ? AppColors.brandGreen
                                      : AppColors.textSecondary.withValues(
                                          alpha: 0.45,
                                        ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _page == pages.length - 1
                                ? 'Swipe back to revisit your story'
                                : 'Swipe to keep going',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyPageData {
  const _JourneyPageData({
    required this.label,
    required this.title,
    required this.diagram,
    required this.commentary,
  });

  final String label;
  final String title;
  final Widget diagram;
  final String commentary;
}

class _JourneyPage extends StatelessWidget {
  const _JourneyPage({required this.data});

  final _JourneyPageData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.brandPurple,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.title,
            style: textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 430, maxHeight: 270),
                child: data.diagram,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              data.commentary,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttemptsDiagram extends StatelessWidget {
  const _AttemptsDiagram({required this.data});

  final VisualizationData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${data.completedAttempts}',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: AppColors.brandGreen,
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(
          'checkboxes completed',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 24),
        _ProgressBar(
            value: data.totalAttempts == 0
                ? 0
                : data.completedAttempts / data.totalAttempts),
        const SizedBox(height: 9),
        Text(
          '${data.totalAttempts} check-ins in the last 30 days',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _StrongestDiagram extends StatelessWidget {
  const _StrongestDiagram({required this.category});

  final VisualizationCategory? category;

  @override
  Widget build(BuildContext context) {
    if (category == null) return const _EmptyDiagram();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.workspace_premium, size: 58, color: AppColors.brandGreen),
        const SizedBox(height: 12),
        Text(
          category!.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 20),
        _ProgressBar(value: category!.rate / 100),
        const SizedBox(height: 8),
        Text(
          '${category!.roundedRate}% completed',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days});

  final List<VisualizationDay> days;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: days.map((day) {
        final height = day.attempts == 0 ? 7.0 : 22 + 116 * day.rate;
        final color = day.attempts == 0
            ? AppColors.textSecondary.withValues(alpha: 0.28)
            : AppColors.brandPurple;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 28,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              day.label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        );
      }).toList(growable: false),
    );
  }
}

class _ReturnDots extends StatelessWidget {
  const _ReturnDots({required this.days});

  final List<VisualizationDay> days;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: days.map((day) {
        final active = day.attempts > 0;
        return Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  active ? AppColors.brandGreen : AppColors.surfaceHigh,
              child: Icon(
                active ? Icons.check : Icons.remove,
                color: active ? AppColors.background : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              day.label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        );
      }).toList(growable: false),
    );
  }
}

class _CareDiagram extends StatelessWidget {
  const _CareDiagram({required this.category});

  final VisualizationCategory? category;

  @override
  Widget build(BuildContext context) {
    if (category == null) return const _EmptyDiagram();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.spa_outlined, size: 58, color: AppColors.brandPurple),
        const SizedBox(height: 12),
        Text(
          category!.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 20),
        _ProgressBar(value: category!.rate / 100, color: AppColors.brandPurple),
        const SizedBox(height: 8),
        Text(
          '${category!.roundedRate}% completed so far',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _CompletionDiagram extends StatelessWidget {
  const _CompletionDiagram({required this.data});

  final VisualizationData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 190,
      child: CustomPaint(
        painter: _CompletionPainter(data.completionRate / 100),
        child: Center(
          child: Text(
            '${data.completionRate.round()}%',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LinearProgressIndicator(
        minHeight: 18,
        value: value.clamp(0.0, 1.0).toDouble(),
        backgroundColor: AppColors.surfaceHigh,
        valueColor:
            AlwaysStoppedAnimation<Color>(color ?? AppColors.brandGreen),
      ),
    );
  }
}

class _EmptyDiagram extends StatelessWidget {
  const _EmptyDiagram();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.auto_awesome, size: 58, color: AppColors.brandGreen),
        const SizedBox(height: 14),
        Text(
          'A blank page can become anything.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}

class _CompletionPainter extends CustomPainter {
  const _CompletionPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 14;
    final background = Paint()
      ..color = AppColors.surfaceHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final foreground = Paint()
      ..color = AppColors.brandGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, background);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(_CompletionPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
