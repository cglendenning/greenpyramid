import 'package:flutter/material.dart';
import '../services/db.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_backdrop.dart';

/// D-178: collects the user's first name once, right before the pyramid is
/// built — a plain, required text-entry screen (owner's own choice over a
/// conversational Mira turn: "a quick, plain text-entry screen... lower
/// friction than a conversation for a single unambiguous fact"). No skip
/// path, matching D-065's PushPermissionScreen precedent for a required
/// one-action screen. The name is then used throughout the app — AI
/// prompts included — in place of generic "you"/"this person" phrasing.
class FirstNameScreen extends StatefulWidget {
  final VoidCallback onDone;
  const FirstNameScreen({super.key, required this.onDone});

  @override
  State<FirstNameScreen> createState() => _FirstNameScreenState();
}

class _FirstNameScreenState extends State<FirstNameScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    await DatabaseHelper.instance.setFirstName(name);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _controller.text.trim().isNotEmpty && !_saving;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: OnboardingBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 5),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  "What's your first name?",
                  style: OnboardingStyles.headline,
                ),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: OnboardingStyles.accentDivider,
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  "So the Council — and everything else in here — can "
                  'actually talk to you like a person, not a placeholder.',
                  style: OnboardingStyles.subhead,
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLength: 40,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _saveAndContinue(),
                    style: const TextStyle(
                        fontFamily: 'Exo2', color: AppColors.textPrimary, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: 'First name',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      border: InputBorder.none,
                      counterStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: canContinue ? _saveAndContinue : null,
                    style: OnboardingStyles.primaryButton,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.background),
                          )
                        : const Text('Continue', style: OnboardingStyles.buttonLabel),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
