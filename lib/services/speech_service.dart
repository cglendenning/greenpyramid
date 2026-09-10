import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';

/// D-124 Phase 5: the batch check-in's voice-recorded miss reason — a
/// near-verbatim port of Kansei's own `speech_service.dart`
/// (`goal-executor/lib/services/speech_service.dart`), wrapping the OS's
/// own native speech recognition (Apple's Speech framework / Android's
/// SpeechRecognizer), not a separate paid transcription service.
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _stoppedByCaller = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (_) => _initialized = false,
    );
    return _initialized;
  }

  bool get isListening => _speech.isListening;
  bool get isAvailable => _initialized;

  Future<void> startListening(void Function(String text) onResult) async {
    if (!_initialized) await initialize();
    _stoppedByCaller = false;
    // iOS commits each phrase as a finalResult then resets partials to
    // empty. Accumulate committed phrases here so the caller always sees
    // the full text.
    String committed = '';

    Future<void> listenOnce() async {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (result.finalResult) {
            if (words.isNotEmpty) {
              committed = committed.isEmpty ? words : '$committed $words';
            }
            onResult(committed);
          } else {
            onResult(committed.isEmpty ? words : '$committed $words');
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: 'en_US',
          listenFor: const Duration(seconds: 120),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
        ),
      );
    }

    // The plugin silently ends the session after `pauseFor` seconds of
    // silence — mid-thought pauses while explaining "what happened" were
    // killing the session with no signal to the UI, so the mic looked
    // like it was still recording while nothing more was being captured.
    // Resume automatically unless the caller (not the plugin) stopped us.
    _speech.statusListener = (status) {
      if (!_stoppedByCaller &&
          (status == SpeechToText.notListeningStatus ||
              status == SpeechToText.doneStatus)) {
        unawaited(listenOnce());
      }
    };

    await listenOnce();
  }

  Future<void> stopListening() async {
    _stoppedByCaller = true;
    await _speech.stop();
  }

  Future<void> cancel() async {
    _stoppedByCaller = true;
    await _speech.cancel();
  }
}
