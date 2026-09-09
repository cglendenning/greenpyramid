import 'dart:math';
import 'package:flutter/material.dart';
import 'package:life_ops/widgets/navbar.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/services/ai_guard.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/entitlement_service.dart';
import 'package:life_ops/services/profile_service.dart';
import 'package:life_ops/services/council_client.dart';
import 'package:life_ops/services/entitlement_gate.dart';
import 'package:life_ops/screens/paywall_screen.dart';

/// D-114: both AI features on this screen — regenerating the vision
/// statement and the 30-day progress analysis — are Claude-backed via
/// [ProfileService], gated by D-016's entitlement check like every other
/// non-setup AI surface. Neither is free, matching how the rest of the
/// app treats Council-powered insight (D-013/D-016) versus the always-free
/// tracker itself (D-015) — the stored vision statement and raw habit
/// history remain visible to everyone; only *generating something new* is
/// gated.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profile = ProfileService.instance;

  String? visionStatement;
  String? newVisionStatement;
  bool isRegenerating = false;
  bool isReviewing = false;
  String? visionError;

  // D-114: generation is now an explicit action, not fired automatically
  // on screen open — the legacy version called the AI unconditionally
  // every time this screen was opened, which is both a paywall surprise
  // for an unentitled account and an unnecessary spend for an entitled
  // one that just wants to check their vision statement.
  String? progressAnalysis;
  bool isLoadingAnalysis = false;
  String? analysisError;

  final List<String> backdropImages = [
    'images/morning_1.jpg',
    'images/afternoon_1.jpg',
    'images/evening_1.jpg',
    'images/evening_2.jpg',
  ];
  late String selectedBackdrop;

  @override
  void initState() {
    super.initState();
    selectedBackdrop = backdropImages[Random().nextInt(backdropImages.length)];
    _loadVisionStatement();
  }

  Future<void> _loadVisionStatement() async {
    final vision = await _profile.loadVisionStatement();
    if (mounted) setState(() => visionStatement = vision);
  }

  /// D-114: found live — this screen's local entitlement cache can say
  /// "trialing"/"subscribed" while the server's own record (Firestore's
  /// `users/{uid}/profile/main`) disagrees, so [_ensureEntitled] passes
  /// and the backend still refuses with 402
  /// ([EntitlementRequiredException], the exception's own doc comment
  /// names exactly this: "the server-authoritative backstop for when a
  /// local cache is stale"). Uncaught, that fell through to the generic
  /// catch-all below and showed a dead-end "please try again" for a
  /// condition retrying can never fix. This resyncs the local cache from
  /// the server (so the next attempt reflects the truth) and sends the
  /// user to the paywall — an actual path forward, not a stuck error.
  Future<void> _handleEntitlementRefusal() async {
    final uid = AuthService.instance.currentUid;
    if (uid != null) {
      await EntitlementService.instance.pullFromServer(uid);
    }
    if (!mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const PaywallScreen(reason: 'Continue with Green Pyramid'),
      ),
    );
  }

  Future<void> _regenerateVisionStatement() async {
    if (!await ensureEntitled(context, reason: 'Regenerate your vision statement')) return;
    if (!mounted) return;
    setState(() {
      isRegenerating = true;
      isReviewing = false;
      newVisionStatement = null;
      visionError = null;
    });
    try {
      final vision = await _profile.regenerateVisionStatement();
      setState(() {
        newVisionStatement = vision;
        isReviewing = true;
        isRegenerating = false;
      });
    } on EntitlementRequiredException {
      setState(() => isRegenerating = false);
      await _handleEntitlementRefusal();
    } on AiBudgetException catch (e) {
      setState(() {
        visionError = e.message;
        isRegenerating = false;
      });
    } on SpendLimitException catch (e) {
      setState(() {
        visionError =
            'You\'ve reached this month\'s spend limit (\$${e.totalSpendUsd.toStringAsFixed(2)}'
                ' of \$${e.spendCapUsd.toStringAsFixed(2)}). More can be purchased soon.';
        isRegenerating = false;
      });
    } on CouncilClientException catch (e) {
      setState(() {
        visionError = e.message;
        isRegenerating = false;
      });
    } catch (e) {
      setState(() {
        visionError = 'Could not generate a vision statement. Please try again.';
        isRegenerating = false;
      });
    }
  }

  Future<void> _replaceVisionStatement() async {
    if (newVisionStatement != null && newVisionStatement!.isNotEmpty) {
      await _profile.saveVisionStatement(newVisionStatement!);
      setState(() {
        visionStatement = newVisionStatement;
        isReviewing = false;
        newVisionStatement = null;
      });
    }
  }

  Future<void> _generateProgressAnalysis() async {
    if (!await ensureEntitled(context, reason: 'See your 30-day progress analysis')) return;
    if (!mounted) return;
    setState(() {
      isLoadingAnalysis = true;
      analysisError = null;
    });
    try {
      final analysis = await _profile.generateProgressAnalysis();
      setState(() {
        progressAnalysis = analysis;
        isLoadingAnalysis = false;
      });
    } on EntitlementRequiredException {
      setState(() => isLoadingAnalysis = false);
      await _handleEntitlementRefusal();
    } on AiBudgetException catch (e) {
      setState(() {
        analysisError = e.message;
        isLoadingAnalysis = false;
      });
    } on SpendLimitException catch (e) {
      setState(() {
        analysisError =
            'You\'ve reached this month\'s spend limit (\$${e.totalSpendUsd.toStringAsFixed(2)}'
                ' of \$${e.spendCapUsd.toStringAsFixed(2)}). More can be purchased soon.';
        isLoadingAnalysis = false;
      });
    } on CouncilClientException catch (e) {
      setState(() {
        analysisError = e.message;
        isLoadingAnalysis = false;
      });
    } catch (e) {
      setState(() {
        analysisError = 'Could not generate your progress analysis. Please try again.';
        isLoadingAnalysis = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: const NavBar(),
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.5), BlendMode.dstATop),
              image: AssetImage(selectedBackdrop),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Your Vision Statement',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 8.0,
                            color: Colors.black,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (visionStatement != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Text(
                          visionStatement!,
                          style: const TextStyle(
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    if (!isRegenerating && !isReviewing)
                      ElevatedButton(
                        onPressed: _regenerateVisionStatement,
                        child: const Text('Regenerate Vision Statement'),
                      ),
                    if (visionError != null && !isRegenerating)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(visionError!,
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center),
                      ),
                    if (isRegenerating)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    if (isReviewing && newVisionStatement != null)
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                              ),
                            ),
                            child: Text(
                              newVisionStatement!,
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _replaceVisionStatement,
                                child: const Text('Replace Existing'),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    isReviewing = false;
                                    newVisionStatement = null;
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 40),
                    Text(
                      'Your Progress (Last 30 Days)',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 8.0,
                            color: Colors.black,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (isLoadingAnalysis)
                      const CircularProgressIndicator()
                    else if (progressAnalysis != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Text(
                          progressAnalysis!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: _generateProgressAnalysis,
                        child: const Text('Generate My Progress Analysis'),
                      ),
                    if (analysisError != null && !isLoadingAnalysis)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(analysisError!,
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
