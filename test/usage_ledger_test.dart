import 'package:flutter_test/flutter_test.dart';
import 'package:life_ops/services/usage_ledger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ledger = UsageLedger.instance;

  test('a fresh install starts with exactly the starter grant', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await ledger.balanceMicros(), UsageLedger.starterGrantMicros);
  });

  test('the starter grant is only ever applied once', () async {
    SharedPreferences.setMockInitialValues({});
    await ledger.balanceMicros(); // triggers init
    await ledger.tryDebit(UsageLedger.starterGrantMicros); // drain to 0
    expect(await ledger.balanceMicros(), 0);
    // A later read must not re-grant the starter.
    expect(await ledger.balanceMicros(), 0);
  });

  test('an ad impression credits net revenue', () async {
    SharedPreferences.setMockInitialValues({
      'usage_ledger_balance_micros': 0,
      'usage_ledger_initialized': true,
    });
    await ledger.creditAdImpression();
    expect(await ledger.balanceMicros(), UsageLedger.adRevenueMicros);
  });

  test('tryDebit spends only when the balance covers the charge', () async {
    SharedPreferences.setMockInitialValues({
      'usage_ledger_balance_micros': UsageLedger.defaultCallCostMicros,
      'usage_ledger_initialized': true,
    });
    expect(await ledger.tryDebit(UsageLedger.defaultCallCostMicros), isTrue);
    expect(await ledger.balanceMicros(), 0);
    // Now empty: the next charge is refused and nothing is spent.
    expect(await ledger.tryDebit(UsageLedger.defaultCallCostMicros), isFalse);
    expect(await ledger.balanceMicros(), 0);
  });

  test('healthy economics: one ad impression funds at least one AI call', () {
    // With mini models a call costs less than one interstitial earns, so a
    // single ad covers a call with margin to spare — a light ad load that
    // stays comfortably solvent. (Solvency itself is enforced by the
    // ledger gate, proved in economic_gate_test; this pins the intended
    // cost/revenue ratio so a future model change that inverts it is
    // caught here.)
    expect(UsageLedger.adRevenueMicros,
        greaterThanOrEqualTo(UsageLedger.defaultCallCostMicros));
  });
}
