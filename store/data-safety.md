# Data safety review worksheet

This is a release-specific review worksheet for the signed 1.44.2 (build 64)
candidate; the Play Console questionnaire must still be filed from these
verified facts.

Privacy policy and external account-deletion resource:
https://greenpyramid-privacy.cglendenning.chatgpt.site

## Identified data surfaces

- Account/provider identifiers: used for sign-in, linking and ownership.
- User-created content: categories, habits, check-ins, explanations, history
  and optional profile fields.
- Purchase and entitlement state: used to unlock paid surfaces and enforce
  server-owned billing/trial rules.
- Calendar context: optional and requested only after the user enables it.
- Diagnostics/analytics: review the final release configuration before filing.

## Controls verified in code

- Authenticated Firebase/App Check boundaries protect backend operations.
- AI calls are entitlement-gated and use bounded request deadlines.
- Local tracker writes work offline where specified.
- There are no advertising SDKs or public rankings in the release package.
- The client does not authoritatively grant subscriptions or trials.
- Account deletion is available in-app at Settings → Account → Delete account
  and through the public privacy-policy resource above.

## Required before submission

File the Data safety and Data deletion answers in Play Console using the exact
signed artifact, then confirm the publisher contact identity and any limited
provider/legal retention wording before submission.
