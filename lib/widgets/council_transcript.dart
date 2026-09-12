import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../models/board_session.dart';
import '../theme/app_colors.dart';
import 'advisor.dart';
import 'typing_indicator.dart';

/// D-091: the message-bubble transcript rendering shared by every screen
/// the Council appears on (setup, category re-clarification, and the
/// general Council chat) — extracted here rather than left duplicated a
/// third time across `setup_screen.dart` and `council_screen.dart`.
///
/// [onAcceptEssence], when non-null, adds an "accept as essence" action
/// under the user's own messages — only `council_screen.dart`'s
/// category-scoped conversation uses this; every other caller omits it.
///
/// D-101: [typingAdvisorKey], when non-null, renders a [TypingIndicator]
/// as the trailing item — every caller passes it only while genuinely
/// awaiting that advisor's reply, never for an unrelated busy state (a
/// data write, a habit commit), so the screen never goes visually dead
/// after the person sends a message but also never claims someone is
/// "typing" when nothing is actually being generated.
class CouncilTranscript extends StatelessWidget {
  final List<BoardMessage> messages;
  final ScrollController? scrollController;
  final void Function(String text)? onAcceptEssence;
  final String? typingAdvisorKey;

  const CouncilTranscript({
    super.key,
    required this.messages,
    this.scrollController,
    this.onAcceptEssence,
    this.typingAdvisorKey,
  });

  @override
  Widget build(BuildContext context) {
    final showTyping = typingAdvisorKey != null;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length + (showTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (showTyping && index == messages.length) {
          return TypingIndicator(advisorKey: typingAdvisorKey!);
        }
        final m = messages[index];
        final isUser = m.advisorKey == 'user';
        final advisor = isUser ? null : AdvisorConfig.forKey(m.advisorKey);
        final bubble = GestureDetector(
          // D-148 (from the same owner report as the auto-scroll fix):
          // "the ability to long press one of the responses from the
          // council and copy it" — the same affordance goal-executor's
          // board_advisors_screen already has.
          onLongPress: () => _copyToClipboard(context, m.text),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.66),
            decoration: BoxDecoration(
              color: (isUser ? AppColors.surfaceHigh : advisor!.bubbleColor)
                  .withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Text(advisor!.name,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                Text(m.text, style: const TextStyle(color: AppColors.textPrimary)),
                if (isUser && onAcceptEssence != null)
                  TextButton(
                    onPressed: () => onAcceptEssence!(m.text),
                    child: const Text('Use as my essence'),
                  ),
              ],
            ),
          ),
        );
        if (isUser) {
          return Align(alignment: Alignment.centerRight, child: bubble);
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: advisor!.fallbackColor,
                backgroundImage: AssetImage(advisor.assetPath),
                onBackgroundImageError: (_, __) {},
              ),
              const SizedBox(width: 8),
              Flexible(child: bubble),
            ],
          ),
        );
      },
    );
  }
}

void _copyToClipboard(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
  );
}
