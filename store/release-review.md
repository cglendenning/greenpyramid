# Release submission review

Reviewed 2026-09-20 against source commit `4385e6075e93b96afa783e432ec694c06b31bf0e`,
Green Pyramid `1.44.2+64`, iOS build `64`, and Android version code `64`.

## Exact artifacts

- Consumer iOS ad-hoc IPA: `build/ios/ipa/Green Pyramid.ipa`; SHA-256
  `154c0414c9e0e491a4177709d27eaf27d91c2cedd55ac2ae67f92e90c358f661`.
- Consumer Android release AAB: `build/app/outputs/bundle/release/app-release.aab`;
  SHA-256 `295ddc9a2fd0721d8d3de0b21a8a5a15e31ad498ddb36fb82077ecab6840e394`.
- Admin iOS ad-hoc IPA: `admin/build/ios/ipa/green_pyramid_admin.ipa`; SHA-256
  `1ee210bf911e411b81b7216bcc8e17828cad0e57a9e974ac6c2d7f3190e17c4f`.

## Apple App Store declaration

- Name: Green Pyramid
- Subtitle: Turn values into daily action
- Primary category: Health & Fitness
- Secondary category: Lifestyle
- Privacy URL: https://greenpyramid-privacy.cglendenning.chatgpt.site
- Target age rating: 4+. The product has no public user-to-user feed, ads,
  gambling, sexual content, profanity, violence or simulated gambling. Private
  user text and advisory AI output are not presented as professional treatment.
- Subscription disclosure: optional auto-renewing subscription; Apple displays
  live price, duration, renewal and cancellation terms before purchase.

## Google Play declaration

- App name: Green Pyramid
- Category: Health & Fitness
- Short description: Turn your values into calm, practical daily action.
- Privacy URL: https://greenpyramid-privacy.cglendenning.chatgpt.site
- Target content rating: Everyone. There is no public user-generated content,
  advertising, gambling, violence or sexual content in the shipped product.
- Data Safety answer set: account identifiers; user-created categories, habits,
  check-ins and history; purchase/entitlement state; optional calendar context;
  analytics events and device/app diagnostics. These are used for account
  operation, tracker synchronization, entitlement enforcement, optional
  guidance, diagnostics and product analytics; authenticated transport is used
  for backend requests; account deletion is available in-app and from the
  public privacy resource. The final console questionnaire must preserve these
  answers and must not declare advertising or public sharing.

## Consistency review

The Apple and Google descriptions use the same promise and distinguish the free
offline tracker from optional entitled AI guidance. Neither listing, screenshot
manifest or reviewer notes contains a price, discount, ranking, testimonial,
guaranteed outcome or scarcity claim. The privacy URL, deletion flow,
subscription disclosure and reviewer path agree across the package.

This file records the reviewed submission answers. It does not represent that
Apple or Google has approved the release or that a console form was submitted.
