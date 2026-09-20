# Staged release and rollback record

Reviewed 2026-09-20 for consumer `1.44.2+64`. The app payload was built from
source commit `4385e6075e93b96afa783e432ec694c06b31bf0e`; the signed-release,
screenshot and store-package wrapper changes are in packaging commit
`dc54589`.

## Smoke matrix

| Path | Evidence | Result |
|---|---|---|
| Fresh release install | Consumer and admin release bundle IDs verified on the paired iPad; consumer screen captured at 1536x2048 after reinstall | Passed on iPad |
| Setup resume/rebuild | `test/d001_setup_test.dart`, `test/setup_rebuild_intent_test.dart`, `test/setup_rebuild_erase_test.dart` | Passed |
| Offline tracking/check-off | `test/sync_service_test.dart` and full Flutter suite | Passed automated |
| Restore/sign-in/account link | `test/account_link_service_test.dart`, `test/auth_service_test.dart` | Passed automated |
| Purchase/restore and entitlement lapse | `test/r8_monetization_test.dart`, `test/analysis_entitlement_test.dart`, Functions entitlement tests | Passed automated; store sandbox still needs console credentials |
| Notification scheduling/tap path | `test/habit_reminder_delivery_test.dart`, `test/settings_screen_wiring_test.dart` | Passed automated |
| Accessibility/reduced-motion behavior | semantics assertions in analysis and screen tests; release source review | Passed source/test review; physical accessibility audit remains owner check |

The focused release-critical Flutter run on 2026-09-20 passed 50 tests:
`test/r8_monetization_test.dart`, `test/analysis_entitlement_test.dart`,
`test/habit_reminder_delivery_test.dart`, `test/account_link_service_test.dart`
and `test/settings_screen_wiring_test.dart`.

## Rollout controls

- Apple: submit the signed IPA for review, release manually after approval, and
  monitor crash-free sessions, launch failures, sign-in failures, entitlement
  mismatch and account-deletion failures.
- Google Play: upload the signed AAB to internal testing first, then staged
  rollout at 5%, 20%, 50% and 100% only after each checkpoint is healthy.
- Stop/rollback thresholds: any crash-on-launch regression, authentication
  failure affecting more than 1% of sessions, entitlement mismatch affecting
  more than 0.5% of protected opens, or confirmed account-deletion failure.
- Rollback: halt the staged rollout, restore the last approved binary, leave
  Firebase Functions and server-owned entitlement state unchanged, and replay
  only authenticated sync operations after recovery. Never grant billing or
  trial state from the client during rollback.

This is an operational release record, not a claim that either store console
has been submitted or approved. Store-console submission and sandbox billing
verification require the publisher's logged-in accounts.
