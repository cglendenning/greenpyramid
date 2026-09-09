/// D-115: pure decision logic for the settings screen's subscription
/// panel, factored out so it's testable without touching the
/// (unmockable) RevenueCat plugin — the same pattern
/// `push_messaging_service.dart`'s `decideNotificationFallback` already
/// establishes for FirebaseMessaging.
///
/// Found live, the hard way: the previous "Manage subscription" entry
/// point always opened a cancel-only screen, even for an account with no
/// real purchase behind it (trialing, lapsed, or pre-trial all look
/// identical to RevenueCat — nothing has ever been bought). Tapping
/// "show me how to cancel" there silently popped back with no way to
/// actually subscribe. [decideSubscriptionPanelState] makes the
/// "is there really something to cancel" check explicit and testable:
/// only [SubscriptionPanelState.activeRenewing] and
/// [SubscriptionPanelState.activeCancelling] represent a real RevenueCat
/// purchase; every other state — including a 3-day trial (D-057), which
/// is server-authoritative and never touches RevenueCat at all — is
/// [SubscriptionPanelState.needsSubscription].
library;

enum SubscriptionPanelState {
  loading,
  activeRenewing,
  activeCancelling,
  needsSubscription,
}

/// [isActive]/[willRenew] come from RevenueCat's own `CustomerInfo` —
/// the authoritative record of whether a real purchase exists (D-070).
/// `null` for [isActive] means the info hasn't loaded yet.
SubscriptionPanelState decideSubscriptionPanelState({
  required bool? isActive,
  bool? willRenew,
}) {
  if (isActive == null) return SubscriptionPanelState.loading;
  if (!isActive) return SubscriptionPanelState.needsSubscription;
  return willRenew == true
      ? SubscriptionPanelState.activeRenewing
      : SubscriptionPanelState.activeCancelling;
}

/// The "subscribe" copy for [SubscriptionPanelState.needsSubscription],
/// tailored to Green Pyramid's own three-state local entitlement cache
/// (`account_state.entitlement`) rather than RevenueCat's, since RevenueCat
/// alone can't distinguish "still in the free trial" from "trial over."
String subscriptionPanelMessage(String? localEntitlement) {
  switch (localEntitlement) {
    case 'trialing':
      return "You're on your free trial. Subscribe now to keep the "
          'Council after it ends.';
    case 'lapsed':
      return 'Your trial has ended. Subscribe to bring the Council back.';
    default:
      return 'Subscribe to unlock the Council, tailored notifications, '
          'and everything your advisors help you see.';
  }
}
