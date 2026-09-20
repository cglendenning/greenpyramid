import 'package:flutter/material.dart';

import '../screens/paywall_screen.dart';
import 'entitlement_service.dart';

/// D-011/D-014: the shared value-triggered paywall gate. Checks entitlement
/// and, if the account isn't trialing or subscribed, pushes the paywall
/// scoped to [reason] — the specific next step the user was already
/// reaching for (D-011's acceptance: every presentation traceable to a
/// concrete moment). Returns true if the caller may proceed.
Future<bool> ensureEntitled(BuildContext context, {required String reason}) async {
  if (await EntitlementService.instance.isEntitled()) return true;
  if (!context.mounted) return false;
  final subscribed = await Navigator.push<bool>(
    context,
    MaterialPageRoute(settings: const RouteSettings(name: 'PaywallScreen'), builder: (context) => PaywallScreen(reason: reason)),
  );
  return subscribed == true;
}
