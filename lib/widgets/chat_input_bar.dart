import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// D-101: the message-composer bar shared by every Council chat screen
/// (setup, category re-clarification, general Council) — extracted after
/// the exact same single-line `TextField` was duplicated three times, with
/// the same defect live in all three copies at once: no `maxLines`, so
/// text scrolled horizontally off-screen instead of wrapping, discovered
/// only when the owner actually typed a real message rather than a short
/// test line.
///
/// Bounded (grows up to [maxLines], then scrolls within its own box, never
/// the screen) and enclosed in a rounded, filled pill — the visual
/// treatment of a messenger app's composer, not a bare Material
/// underline field. Return inserts a newline (`TextInputAction.newline`);
/// sending is the up-arrow button or a hardware-keyboard submit, matching
/// how iMessage/WhatsApp-style composers behave.
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final VoidCallback onSubmit;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSubmit,
    this.hintText = 'Say more…',
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: enabled ? onSubmit : null,
              icon: const Icon(Icons.arrow_upward, color: AppColors.brandGreen),
            ),
          ],
        ),
      ),
    );
  }
}
