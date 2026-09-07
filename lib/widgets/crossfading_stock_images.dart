import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../utils/stock_images.dart';

/// D-090: the welcome screen's rotating background, ported verbatim
/// (behavior and timing) from Kansei's `CrossfadingStockImages`
/// (goal-executor/lib/widgets/crossfading_stock_images.dart), which uses
/// this exact rhythm on its own setup-analog screen (igniter_screen.dart).
/// Cycles through all 20 stock images in a random order, crossfading every
/// 5 seconds over a 3-second transition.
class CrossfadingStockImages extends StatefulWidget {
  const CrossfadingStockImages({super.key});

  @override
  State<CrossfadingStockImages> createState() =>
      _CrossfadingStockImagesState();
}

class _CrossfadingStockImagesState extends State<CrossfadingStockImages> {
  late final List<String> _images;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _images = List.of(kStockImages)..shuffle(Random());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _images.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(seconds: 3),
      child: SizedBox.expand(
        key: ValueKey(_index),
        child: Image.asset(_images[_index], fit: BoxFit.cover),
      ),
    );
  }
}
