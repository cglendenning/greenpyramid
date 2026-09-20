# Data safety review worksheet

This is a release-specific working sheet, not a substitute for the Play
Console questionnaire.

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

## Required before submission

Confirm the final privacy URL, deletion workflow, retention wording, contact
identity and exact SDK/data disclosures against the signed artifact.
