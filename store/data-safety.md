# Data safety review worksheet

This is the release-specific review worksheet for Green Pyramid 1.44.2 (build
64). The exact reviewed declaration set is recorded in `store/release-review.md`.

Privacy policy and external account-deletion resource:
https://greenpyramid-privacy.cglendenning.chatgpt.site

## Identified data surfaces

- Account/provider identifiers: used for sign-in, linking and ownership.
- User-created content: categories, habits, check-ins, explanations, history
  and optional profile fields.
- Purchase and entitlement state: used to unlock paid surfaces and enforce
  server-owned billing/trial rules.
- Calendar context: optional and requested only after the user enables it.
- Analytics events and device/app diagnostics: used for product measurement and
  reliability; review the final console labels against the exact platform form.

## Controls verified in code

- Authenticated Firebase/App Check boundaries protect backend operations.
- AI calls are entitlement-gated and use bounded request deadlines.
- Local tracker writes work offline where specified.
- There are no advertising SDKs or public rankings in the release package.
- The client does not authoritatively grant subscriptions or trials.
- Account deletion is available in-app at Settings → Account → Delete account
  and through the public privacy-policy resource above.

## Submission control

File the Data safety and Data deletion answers in Play Console using the exact
artifact and declaration set above, then confirm the publisher contact identity
and any limited provider/legal retention wording before submission. This package
does not claim that an external console form has been submitted.
