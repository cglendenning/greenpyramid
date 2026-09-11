import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:life_ops/screens/council_category_picker.dart';
import 'package:life_ops/screens/cancel_subscription_screen.dart';
import 'package:life_ops/screens/domain_map_screen.dart';
import 'package:life_ops/screens/paywall_screen.dart';
import 'package:life_ops/screens/welcome_screen.dart';
import 'package:life_ops/services/account_link_service.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/calendar_service.dart';
import 'package:life_ops/services/entitlement_gate.dart';
import 'package:life_ops/services/entitlement_service.dart';
import 'package:life_ops/services/notification.dart';
import 'package:life_ops/services/subscription_panel_logic.dart';
import 'package:life_ops/services/subscription_service.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'dart:io' show Platform;

Future<void> showPreviewWarningDialog(BuildContext context) async {
  if (!Platform.isIOS) return; // Only show on iOS

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('How to Show Notification Previews',
          style: TextStyle(color: AppColors.textPrimary)),
      content: SizedBox(
        width: 350,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To see the full content of notifications, you must set "Show Previews" to "Always" for Green Pyramid notifications.\n',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const Text(
                'Step 1:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Image.asset(
                'images/previews1.jpg',
                fit: BoxFit.contain,
                width: 320,
                height: 220,
              ),
              const SizedBox(height: 8),
              const Text(
                'Open your iPhone Settings, scroll down and tap on "Green Pyramid", then tap "Notifications".',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Step 2:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Image.asset(
                'images/previews2.jpg',
                fit: BoxFit.contain,
                width: 320,
                height: 220,
              ),
              const SizedBox(height: 8),
              const Text(
                'Scroll down to "Show Previews" and set it to "Always". This will allow notification content to be visible.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              const Text(
                'After making this change, return to the app and test notifications again.',
                style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (await canLaunchUrl(Uri.parse('app-settings:'))) {
              await launchUrl(Uri.parse('app-settings:'));
            }
            Navigator.of(context).pop();
          },
          child: const Text('Open Notification Settings'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

/// D-115: rebuilt on Kansei's settings-screen layout (`goal-executor`'s
/// `settings_screen.dart`) — sectioned cards, an entitlement-aware
/// subscription panel, and a "send test notification" control that
/// mirrors Kansei's identical feature. Stays an embedded homescreen tab
/// (D-024's `IndexedStack`), not a pushed screen, so it carries no
/// `AppBar` of its own.
class Settings extends StatefulWidget {
  const Settings();

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  late final LocalNotificationService lns;

  @override
  void initState() {
    super.initState();
    lns = LocalNotificationService();
    lns.intialize();
  }

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'settings');

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _sectionLabel('SUBSCRIPTION'),
            _card(child: const _SubscriptionPanel()),
            const SizedBox(height: 28),

            _sectionLabel('NOTIFICATIONS'),
            _card(child: _TestNotificationButton(lns: lns)),
            if (Platform.isIOS) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => showPreviewWarningDialog(context),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('Adjust Previews'),
                ),
              ),
            ],
            const SizedBox(height: 28),

            _sectionLabel('THE COUNCIL'),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // D-061: Council re-clarification entry point.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const CouncilCategoryPicker()),
                        );
                      },
                      child: const Text(
                          'Revisit a category with the Council of Advisors'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // D-049: the domain map — a destination visited
                  // deliberately, gated as a paid capability (D-016).
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () async {
                        final allowed = await ensureEntitled(context,
                            reason: 'See your domain map');
                        if (!allowed || !context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const DomainMapScreen()),
                        );
                      },
                      child: const Text('Your domain map'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionLabel('CALENDAR'),
            // D-025 step 7: opt-in only, requested here — never on launch.
            _card(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Expanded(
                    child: Text(
                        'Let the Council of Advisors see your calendar',
                        style: TextStyle(color: AppColors.textPrimary)),
                  ),
                  CalendarAccessSwitch(),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionLabel('ACCOUNT'),
            _card(child: const _AccountSection()),
          ],
        ),
      ),
    );
  }
}

/// D-115: mirrors Kansei's inline subscription panel — branches on
/// RevenueCat's own `CustomerInfo` ([decideSubscriptionPanelState]) rather
/// than assuming a purchase exists. Found live: the previous "Manage
/// subscription" link always opened a cancel-only screen, even for a
/// trialing account with nothing to cancel.
class _SubscriptionPanel extends StatefulWidget {
  const _SubscriptionPanel();

  @override
  State<_SubscriptionPanel> createState() => _SubscriptionPanelState();
}

class _SubscriptionPanelState extends State<_SubscriptionPanel> {
  CustomerInfo? _info;
  bool _loading = true;
  String? _localEntitlement;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await SubscriptionService.syncAndGetCustomerInfo();
    final localEntitlement = await EntitlementService.instance.currentLocalEntitlement();
    if (!mounted) return;
    setState(() {
      _info = info;
      _localEntitlement = localEntitlement;
      _loading = false;
    });
  }

  Future<void> _openPaywall() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const PaywallScreen(reason: 'Subscribe to Green Pyramid'),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openManage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CancelSubscriptionScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    final entitlement = _info?.entitlements.active.values.firstOrNull;
    final state = decideSubscriptionPanelState(
      isActive: entitlement?.isActive ?? false,
      willRenew: entitlement?.willRenew,
    );

    switch (state) {
      case SubscriptionPanelState.loading:
        return const LinearProgressIndicator(minHeight: 2);

      case SubscriptionPanelState.activeRenewing:
        final expiry = entitlement!.expirationDate != null
            ? DateTime.tryParse(entitlement.expirationDate!)
            : null;
        final expiryStr = expiry != null
            ? DateFormat("MMM d 'at' h:mm a").format(expiry.toLocal())
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              expiryStr != null
                  ? 'Subscribed — renews $expiryStr'
                  : 'Active subscription',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: _openManage,
                child: const Text('Manage subscription'),
              ),
            ),
          ],
        );

      case SubscriptionPanelState.activeCancelling:
        final expiry = entitlement!.expirationDate != null
            ? DateTime.tryParse(entitlement.expirationDate!)
            : null;
        final expiryStr = expiry != null
            ? DateFormat("MMM d 'at' h:mm a").format(expiry.toLocal())
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              expiryStr != null
                  ? 'Cancellation pending — access until $expiryStr'
                  : 'Subscription cancelled',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openPaywall,
                child: const Text('Resubscribe'),
              ),
            ),
          ],
        );

      case SubscriptionPanelState.needsSubscription:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subscriptionPanelMessage(_localEntitlement),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openPaywall,
                child: const Text('Subscribe'),
              ),
            ),
          ],
        );
    }
  }
}

/// D-115: schedules a single local test notification, mirroring Kansei's
/// identical settings-screen control.
class _TestNotificationButton extends StatefulWidget {
  const _TestNotificationButton({required this.lns});
  final LocalNotificationService lns;

  @override
  State<_TestNotificationButton> createState() => _TestNotificationButtonState();
}

class _TestNotificationButtonState extends State<_TestNotificationButton> {
  bool _pending = false;
  bool _scheduling = false;

  @override
  void initState() {
    super.initState();
    widget.lns.isTestNotificationPending().then((p) {
      if (mounted) setState(() => _pending = p);
    });
  }

  Future<void> _send() async {
    setState(() => _scheduling = true);
    try {
      await widget.lns.scheduleTestNotification();
      if (mounted) setState(() => _pending = true);
    } finally {
      if (mounted) setState(() => _scheduling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _pending
              ? 'A test notification is scheduled — it will fire in about a minute. Come back after it fires to send another.'
              : 'Schedule a notification 1 minute from now to confirm delivery is working.',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: (_pending || _scheduling) ? null : _send,
            child: _scheduling
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_pending ? 'Pending…' : 'Send test notification'),
          ),
        ),
      ],
    );
  }
}

/// D-025 step 7: reflects and toggles calendar read access. Turning it on
/// prompts the OS permission dialog; turning it off only stops the app from
/// reading the calendar going forward — revoking the OS grant itself
/// happens in system settings, same as every other permission in this app.
class CalendarAccessSwitch extends StatefulWidget {
  const CalendarAccessSwitch({super.key});

  @override
  State<CalendarAccessSwitch> createState() => _CalendarAccessSwitchState();
}

class _CalendarAccessSwitchState extends State<CalendarAccessSwitch> {
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    CalendarService.instance.hasPermission().then((granted) {
      if (mounted) setState(() => _granted = granted);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: _granted,
      activeColor: AppColors.brandGreen,
      onChanged: (value) async {
        if (!value) {
          setState(() => _granted = false);
          return;
        }
        final granted = await CalendarService.instance.requestPermission();
        if (mounted) setState(() => _granted = granted);
      },
    );
  }
}

/// D-132/D-133: shows the linked provider (if any) and lets the user sign
/// out — the same underlying flow the hamburger menu's "Sign out" item
/// now also offers (homescreen.dart's CustomAppBarState.signOut). After
/// sign-out, a fresh anonymous session is re-established immediately
/// (AuthService.signInSilently) — every Firestore-touching screen in this
/// app assumes at least an anonymous uid exists (D-032) — before routing
/// to WelcomeScreen(isResetup: true), where the user picks "Sign in" (to
/// the same or a different account) or "Set up again."
class _AccountSection extends StatefulWidget {
  const _AccountSection();

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  bool _signingOut = false;

  String? get _providerLabel {
    final providers = FirebaseAuth.instance.currentUser?.providerData ?? const [];
    for (final p in providers) {
      if (p.providerId == 'apple.com') return 'Signed in with Apple';
      if (p.providerId == 'google.com') return 'Signed in with Google';
    }
    return null;
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign out?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Your pyramid and history are saved to your account.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    await AccountLinkService.instance.signOut();
    await AuthService.instance.signInSilently();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(isResetup: true),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerLabel = _providerLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          providerLabel ?? 'Not signed in with a real account yet',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: _signingOut ? null : _confirmSignOut,
            child: _signingOut
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign out'),
          ),
        ),
      ],
    );
  }
}
