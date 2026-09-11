import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:life_ops/services/feedback_service.dart';
import 'package:life_ops/theme/app_colors.dart';

/// D-129: replaces the old mailto-based feedback screen. Frictionless by
/// design — pick a category (required, one tap), optionally add up to
/// [FeedbackService.maxCommentLength] characters of specifics, send. No
/// open-ended "subject"/"body" freeform pair.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  FeedbackCategory? _category;
  final _commentController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _analytics.logEvent(name: 'feedback_screen');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final category = _category;
    if (category == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final info = await PackageInfo.fromPlatform();
      await FeedbackService.instance.submit(
        category: category,
        comment: _commentController.text,
        appVersion: info.version,
        buildNumber: info.buildNumber,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      unawaited(_analytics.logEvent(
        name: 'feedback_submitted',
        parameters: {'category': category.wireValue},
      ));
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (error) {
      if (kDebugMode) {
        print('Feedback submit failed: $error');
      }
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = "Couldn't send that — check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('App Feedback')),
      body: SafeArea(
        child: _submitted ? _buildThanks() : _buildForm(),
      ),
    );
  }

  Widget _buildThanks() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Got it — thank you.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFamily: 'Exo2',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'I read every one of these myself.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Exo2',
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => setState(() {
                _submitted = false;
                _category = null;
                _commentController.clear();
              }),
              child: const Text('Send more feedback'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        const Text(
          "What's this about?",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Exo2',
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: FeedbackCategory.values.map((c) {
            final selected = _category == c;
            return ChoiceChip(
              label: Text(c.label),
              selected: selected,
              onSelected: (_) => setState(() => _category = c),
              selectedColor: AppColors.brandGreen,
              backgroundColor: AppColors.surfaceHigh,
              side: BorderSide.none,
              labelStyle: TextStyle(
                fontFamily: 'Exo2',
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.background : AppColors.textPrimary,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        const Text(
          'Add specifics (optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Exo2',
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentController,
          maxLength: FeedbackService.maxCommentLength,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Exo2'),
          decoration: InputDecoration(
            hintText: 'What screen, what happened...',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            counterStyle: const TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_category == null || _submitting) ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Send'),
          ),
        ),
      ],
    );
  }
}
