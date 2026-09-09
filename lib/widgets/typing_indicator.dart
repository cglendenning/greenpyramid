import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'advisor.dart';

/// D-101: shown as the last item in a Council transcript while waiting for
/// an advisor's reply, so the screen never simply goes dead after the
/// person sends a message — the same three-pulsing-dots convention every
/// major messenger app uses for "the other person is composing a reply."
///
/// Same reduce-motion discipline as [SetupProgressIndicator] (D-044):
/// static dots, no animation ticks, whenever the platform requests it.
class TypingIndicator extends StatefulWidget {
  final String advisorKey;
  const TypingIndicator({super.key, required this.advisorKey});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;
  // D-107: found live — "reduceMotion == _reduceMotion" as the sole guard
  // meant the very first call, the overwhelmingly common case where the
  // real MediaQuery value is also false, short-circuited before ever
  // calling _controller.repeat() at all: false == false is true, so the
  // "first configuration" and "no change since last time" cases were
  // indistinguishable. The dots rendered, but frozen at the controller's
  // initial value — motion never actually started. This flag makes "have
  // we configured this at all yet" a fact of its own, not inferred from
  // whether the value happens to match the field's default.
  bool _reduceMotionInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotionInitialized && reduceMotion == _reduceMotion) return;
    _reduceMotionInitialized = true;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _dotOpacity(int index) {
    // Three dots, each offset by a third of the cycle, fading
    // 0.3 -> 1.0 -> 0.3 in a loop (a triangle wave over the controller's
    // 0..1 value).
    final t = (_controller.value + index / 3) % 1.0;
    final wave = 1 - (2 * t - 1).abs();
    return 0.3 + wave * 0.7;
  }

  Widget _dotsRow(List<double> opacities) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Opacity(
            opacity: opacities[i],
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.textPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final advisor = AdvisorConfig.forKey(widget.advisorKey);
    final dots = _reduceMotion
        ? _dotsRow(const [1.0, 1.0, 1.0])
        : AnimatedBuilder(
            animation: _controller,
            builder: (context, _) =>
                _dotsRow([_dotOpacity(0), _dotOpacity(1), _dotOpacity(2)]),
          );

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: advisor.bubbleColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: dots,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: advisor.fallbackColor,
            backgroundImage: AssetImage(advisor.assetPath),
            onBackgroundImageError: (_, __) {},
          ),
          const SizedBox(width: 8),
          bubble,
        ],
      ),
    );
  }
}
