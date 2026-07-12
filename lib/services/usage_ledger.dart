import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The economic guardrail that keeps the app solvent: a per-install ledger,
// denominated in micro-dollars (millionths of a USD), that ad impressions
// CREDIT and OpenAI calls DEBIT. An AI call is only allowed when the ledger
// can cover its (conservatively over-estimated) cost, so cumulative API
// spend can never exceed cumulative ad revenue (plus the one bounded
// starter grant below).
//
// Why the invariant holds:
//   - Each call is charged [defaultCallCostMicros], set ABOVE the real cost
//     of the most expensive model call, so we never under-charge.
//   - Each impression credits [adRevenueMicros], set BELOW real net eCPM, so
//     we never over-credit.
//   - A call is refused unless balance >= its charge.
//   => real_spend <= charged <= credited + starter <= real_revenue + starter.
//
// The three constants are the business knobs. Tune [adRevenueMicros] to at
// or below your observed net interstitial eCPM/1000; raise
// [defaultCallCostMicros] if you move to a pricier model. The future
// rewarded-interstitial ("watch to earn more usage") simply credits this
// same ledger on a rewarded impression — no other change is needed.
class UsageLedger {
  UsageLedger._();
  static final UsageLedger instance = UsageLedger._();

  // Conservative NET revenue per interstitial impression. $0.004 assumes a
  // net eCPM of at least $4; set this at or below your real net eCPM/1000.
  static const int adRevenueMicros = 4000;

  // Conservative cost charged per AI call. $0.003 sits above a
  // gpt-4o-mini / gpt-4.1-mini call carrying the app's context (the app
  // uses only mini models); cheaper calls are over-charged, which only
  // makes the app more solvent. At this rate a single interstitial funds
  // more than one AI call, so the ad load stays light.
  static const int defaultCallCostMicros = 3000;

  // The ONLY spend permitted before any ad revenue: a one-time per-install
  // allowance so first-run onboarding (task generation, vision statement,
  // first coaching reply) works before the user has seen ads. This is a
  // bounded customer-acquisition cost. Set to 0 for a strictly
  // revenue-first policy (onboarding would then require watching ads).
  static const int starterGrantMicros = 150000;

  static const String _balanceKey = 'usage_ledger_balance_micros';
  static const String _initializedKey = 'usage_ledger_initialized';

  Future<void> _ensureInitialized(SharedPreferences prefs) async {
    if (prefs.getBool(_initializedKey) == true) return;
    await prefs.setInt(_balanceKey, starterGrantMicros);
    await prefs.setBool(_initializedKey, true);
  }

  Future<int> balanceMicros() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureInitialized(prefs);
    return prefs.getInt(_balanceKey) ?? 0;
  }

  // Records net revenue from one confirmed ad impression.
  Future<void> creditAdImpression() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureInitialized(prefs);
    final balance = prefs.getInt(_balanceKey) ?? 0;
    await prefs.setInt(_balanceKey, balance + adRevenueMicros);
    debugPrint('UsageLedger: +$adRevenueMicros micros (ad); '
        'balance ${balance + adRevenueMicros}');
  }

  // Charges [costMicros] for an AI call. Returns false (and does not spend)
  // when the balance can't cover it, so the caller must refuse the call.
  Future<bool> tryDebit(int costMicros) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureInitialized(prefs);
    final balance = prefs.getInt(_balanceKey) ?? 0;
    if (balance < costMicros) {
      debugPrint('UsageLedger: refused debit of $costMicros; '
          'balance $balance');
      return false;
    }
    await prefs.setInt(_balanceKey, balance - costMicros);
    return true;
  }
}
