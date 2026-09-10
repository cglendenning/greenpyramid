import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_ops/services/speech_service.dart';
import 'package:life_ops/theme/app_colors.dart';

/// D-124 Phase 5: a near-verbatim port of Kansei's own
/// `MicrophoneRecorder` (`goal-executor/lib/widgets/microphone_recorder.dart`)
/// — tap to start/stop, a pulsing ring while listening, and a running
/// elapsed-time label — restyled onto Green Pyramid's own palette.
class MicrophoneRecorder extends StatefulWidget {
  final SpeechService speechService;
  final void Function(String transcript) onTranscriptChanged;

  const MicrophoneRecorder({
    super.key,
    required this.speechService,
    required this.onTranscriptChanged,
  });

  @override
  State<MicrophoneRecorder> createState() => _MicrophoneRecorderState();
}

class _MicrophoneRecorderState extends State<MicrophoneRecorder>
    with SingleTickerProviderStateMixin {
  bool _listening = false;
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    if (_listening) widget.speechService.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    HapticFeedback.mediumImpact();
    if (_listening) {
      await widget.speechService.stopListening();
      _timer?.cancel();
      _pulseController.stop();
      _pulseController.reset();
      if (mounted) setState(() => _listening = false);
    } else {
      final ok = await widget.speechService.initialize();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Speech recognition not available.')),
          );
        }
        return;
      }
      setState(() {
        _listening = true;
        _seconds = 0;
      });
      _pulseController.repeat(reverse: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
      await widget.speechService.startListening((text) {
        widget.onTranscriptChanged(text);
      });
    }
  }

  String get _elapsed {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          ScaleTransition(
            scale: _listening
                ? _pulseAnimation
                : const AlwaysStoppedAnimation(1.0),
            child: GestureDetector(
              onTap: _toggle,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _listening
                      ? Colors.redAccent
                      : AppColors.brandGreen.withOpacity(0.12),
                  border: Border.all(
                    color: _listening ? Colors.redAccent : AppColors.brandGreen,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _listening ? Icons.stop : Icons.mic,
                  size: 36,
                  color: _listening ? Colors.white : AppColors.brandGreen,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _listening ? 'Recording  $_elapsed' : 'Tap to record',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _listening ? Colors.redAccent : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
