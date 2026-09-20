# Store reviewer notes

## Current build

- Version: `1.44.2`
- Build: `64`
- iOS bundle ID: `com.cglendenning.lifeops`
- Android application ID: `com.cglendenning.life_ops`
- Privacy policy: https://greenpyramid-privacy.cglendenning.chatgpt.site

## Reproducible review path

1. Install the submitted build and launch Green Pyramid.
2. Complete the guided setup, or use the supplied review account if the store
   portal requires authenticated access.
3. Use the first bottom-navigation destination to inspect the pyramid and the
   second destination to check off habits. These tracker operations are free
   and remain available offline.
4. Open Settings to test notification and calendar permission controls. Denied
   permissions produce an in-app explanation and recovery path.
5. Link an Apple or Google account from the account section and relaunch to
   verify restore behavior. Do not use a reviewer account containing personal
   data.
6. For subscription behavior, use the platform sandbox account. The paywall
   displays the live product terms; restore is available from the paywall.
7. With a trialing or subscribed sandbox account, select Analysis. The six-page
   journey reads local history only. General Council, category Council and
   paid notification actions use the same entitlement gate.
8. Turn off network access after entitlement is known and verify local tracking
   continues. A new entitlement is never fabricated while offline.
9. Open Settings → Account → Delete account. Confirm the permanent-deletion
   warning, then verify the app returns to the signed-out welcome screen. Store
   subscriptions must be cancelled separately in Apple or Google settings.

## Data and feature disclosures

- AI processing is authenticated, server-mediated and limited by entitlement,
  spend reservation and request deadlines.
- Calendar access is optional and requested from Settings, not on launch.
- Notifications are optional; denied permission does not block tracking.
- Saved tracker content and account-linked content are scoped to the account.
- Billing authority and trial authority remain server/store-owned; clients do
  not grant entitlement from arbitrary local values.
