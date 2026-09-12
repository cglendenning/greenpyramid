import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:life_ops/widgets/navbar.dart';
import 'package:life_ops/widgets/crossfading_stock_images.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/services/ai_guard.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/entitlement_service.dart';
import 'package:life_ops/services/profile_service.dart';
import 'package:life_ops/services/council_client.dart';
import 'package:life_ops/services/entitlement_gate.dart';
import 'package:life_ops/services/sync_service.dart';
import 'package:life_ops/screens/paywall_screen.dart';

/// D-178: revamped per the owner's own request — "Re-vamp the profile
/// screen to contain our standard multi-photo rotation of the 20 photos
/// and to look beautiful," plus new fields for first name, a local
/// photo, email, and phone ("any other info they want to store"),
/// explicitly pure personal reference with no functional behavior
/// (never used for verification, recovery, or notifications). The
/// background is now [CrossfadingStockImages] — the same rotating
/// 20-photo treatment every other onboarding-family screen already
/// uses — replacing this screen's own private 4-image rotation.
///
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
  final _db = DatabaseHelper.instance;

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

  // D-178: personal info — pure reference fields, no functional
  // behavior. Saved locally on every change and synced in the
  // background (except the photo, which stays local-only), matching
  // D-172's established "sync after a real mutation" discipline.
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? photoPath;
  bool _loadingAccountInfo = true;

  @override
  void initState() {
    super.initState();
    _loadAccountInfo();
    _loadVisionStatement();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountInfo() async {
    final account = await _db.getAccountState();
    if (!mounted) return;
    setState(() {
      _nameController.text = account[DatabaseHelper.columnFirstName] as String? ?? '';
      _emailController.text = account[DatabaseHelper.columnEmail] as String? ?? '';
      _phoneController.text = account[DatabaseHelper.columnPhone] as String? ?? '';
      photoPath = account[DatabaseHelper.columnProfilePhotoPath] as String?;
      _loadingAccountInfo = false;
    });
  }

  void _syncInBackground() {
    final uid = AuthService.instance.currentUid;
    if (uid != null) {
      unawaited(SyncService.instance.syncAll(uid, setupComplete: true));
    }
  }

  Future<void> _saveFirstName(String value) async {
    await _db.setFirstName(value.trim());
    _syncInBackground();
  }

  Future<void> _saveEmail(String value) async {
    await _db.setEmail(value.trim());
    _syncInBackground();
  }

  Future<void> _savePhone(String value) async {
    await _db.setPhone(value.trim());
    _syncInBackground();
  }

  /// D-178: the photo is deliberately local-only (owner's own choice over
  /// adding Firebase Storage, a new cloud integration not yet approved) —
  /// no sync call here, unlike the three text fields above. The picked
  /// file is copied out of image_picker's own temp location into the
  /// app's documents directory under a fixed name, since a temp picker
  /// file isn't guaranteed to survive past this session.
  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/profile_photo.jpg');
    await File(picked.path).copy(dest.path);
    await _db.setProfilePhotoPath(dest.path);
    if (!mounted) return;
    setState(() => photoPath = dest.path);
  }

  Future<void> _removePhoto() async {
    final current = photoPath;
    await _db.setProfilePhotoPath(null);
    if (!mounted) return;
    setState(() => photoPath = null);
    if (current != null) {
      final file = File(current);
      if (await file.exists()) await file.delete();
    }
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

  static const _fieldLabelStyle = TextStyle(
      fontFamily: 'Exo2',
      fontWeight: FontWeight.w600,
      fontSize: 12,
      letterSpacing: 0.8,
      color: AppColors.textSecondary);

  static final ButtonStyle _primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.brandGreen,
    foregroundColor: AppColors.background,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: child,
      );

  Widget _sectionHeading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Exo2',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      );

  Widget _infoField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _fieldLabelStyle),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            onChanged: onChanged,
            style: const TextStyle(
                fontFamily: 'Exo2', color: AppColors.textPrimary, fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoAvatar() {
    final path = photoPath;
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickPhoto,
            child: CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.surfaceHigh,
              backgroundImage: path != null ? FileImage(File(path)) : null,
              child: path == null
                  ? const Icon(Icons.person, size: 44, color: AppColors.textSecondary)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _pickPhoto,
                child: Text(path == null ? 'Add photo' : 'Change photo',
                    style: const TextStyle(fontFamily: 'Exo2', color: AppColors.brandGreen)),
              ),
              if (path != null)
                TextButton(
                  onPressed: _removePhoto,
                  child: const Text('Remove',
                      style: TextStyle(fontFamily: 'Exo2', color: AppColors.textSecondary)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NavBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CrossfadingStockImages(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0.55),
                  AppColors.background.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionHeading('Your Profile'),
                  _card(
                    child: _loadingAccountInfo
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(color: AppColors.brandGreen),
                            ),
                          )
                        : Column(
                            children: [
                              _photoAvatar(),
                              const SizedBox(height: 20),
                              _infoField(
                                label: 'FIRST NAME',
                                controller: _nameController,
                                capitalization: TextCapitalization.words,
                                onChanged: _saveFirstName,
                              ),
                              const SizedBox(height: 16),
                              _infoField(
                                label: 'EMAIL',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                onChanged: _saveEmail,
                              ),
                              const SizedBox(height: 16),
                              _infoField(
                                label: 'PHONE',
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                onChanged: _savePhone,
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 32),
                  _sectionHeading('Your Vision Statement'),
                  _card(
                    child: Column(
                      children: [
                        if (visionStatement != null)
                          Text(
                            visionStatement!,
                            style: const TextStyle(fontSize: 17, color: AppColors.textPrimary),
                            textAlign: TextAlign.center,
                          )
                        else
                          const CircularProgressIndicator(color: AppColors.brandGreen),
                        const SizedBox(height: 20),
                        if (!isRegenerating && !isReviewing)
                          ElevatedButton(
                            onPressed: _regenerateVisionStatement,
                            style: _primaryButtonStyle,
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
                            child: CircularProgressIndicator(color: AppColors.brandGreen),
                          ),
                        if (isReviewing && newVisionStatement != null)
                          Column(
                            children: [
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  newVisionStatement!,
                                  style: const TextStyle(
                                      fontSize: 16, color: AppColors.textPrimary),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: _replaceVisionStatement,
                                    style: _primaryButtonStyle,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _sectionHeading('Your Progress (Last 30 Days)'),
                  _card(
                    child: Column(
                      children: [
                        if (isLoadingAnalysis)
                          const CircularProgressIndicator(color: AppColors.brandGreen)
                        else if (progressAnalysis != null)
                          Text(
                            progressAnalysis!,
                            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                            textAlign: TextAlign.center,
                          )
                        else
                          ElevatedButton(
                            onPressed: _generateProgressAnalysis,
                            style: _primaryButtonStyle,
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
