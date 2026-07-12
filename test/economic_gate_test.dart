import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/ai_guard.dart';
import 'package:life_ops/services/usage_ledger.dart';
import 'package:shared_preferences/shared_preferences.dart';

// End-to-end proof of the solvency guardrail: AiGuard.acquire (the single
// chokepoint every OpenAI call passes through) refuses when the ad-funded
// ledger can't cover the call, and ad impressions free it back up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ledger = UsageLedger.instance;

  test('acquire is refused when the ad-funded ledger is empty', () async {
    SharedPreferences.setMockInitialValues({
      'usage_ledger_balance_micros': 0,
      'usage_ledger_initialized': true,
    });
    await expectLater(
      AiGuard.instance.acquire(at: DateTime(2030, 1, 1)),
      throwsA(isA<AiBudgetException>()),
    );
  });

  test('acquire succeeds while the ledger is funded', () async {
    SharedPreferences.setMockInitialValues({
      'usage_ledger_balance_micros': UsageLedger.defaultCallCostMicros,
      'usage_ledger_initialized': true,
    });
    await AiGuard.instance.acquire(at: DateTime(2030, 2, 1));
    // That one call drained the ledger, so the next is refused.
    await expectLater(
      AiGuard.instance.acquire(at: DateTime(2030, 2, 1, 0, 2)),
      throwsA(isA<AiBudgetException>()),
    );
  });

  test('ad impressions unblock a previously-refused call', () async {
    SharedPreferences.setMockInitialValues({
      'usage_ledger_balance_micros': 0,
      'usage_ledger_initialized': true,
    });
    await expectLater(
      AiGuard.instance.acquire(at: DateTime(2030, 3, 1)),
      throwsA(isA<AiBudgetException>()),
    );
    // Show enough ads to cover exactly one call, then it goes through.
    while ((await ledger.balanceMicros()) <
        UsageLedger.defaultCallCostMicros) {
      await ledger.creditAdImpression();
    }
    await AiGuard.instance.acquire(at: DateTime(2030, 3, 2));
  });
}
