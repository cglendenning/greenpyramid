# Store submission package

Release candidate: Green Pyramid 1.44.2 (build 64), bundle ID
`com.cglendenning.lifeops`, Android application ID `com.cglendenning.life_ops`.

This package contains the reviewed listing copy, reviewer notes, privacy/data
declaration set, screenshot manifests, release review and staged-release record.

The public privacy policy is available at
https://greenpyramid-privacy.cglendenning.chatgpt.site. The app provides an
in-app account-deletion flow at Settings → Account → Delete account, including
cloud account/data erasure, local cleanup and a subscription cancellation
disclosure.

The screenshot capture runner is `scripts/capture_store_screenshots.sh`.
The checked-in phone artwork is the current-dimension set: five 1320x2868
Apple screenshots and five 1080x1920 Google Play screenshots. A physical iPad
release screenshot was verified at 1536x2048 using `devicectl`; the full
Flutter screenshot runner remains a development-only capture tool because its
VM channel requires local-network permission. No screenshot is represented as
captured by that runner unless it exists in the manifest.
