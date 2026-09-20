# Store submission package

Release candidate: Green Pyramid 1.44.2 (build 64), bundle ID
`com.cglendenning.lifeops`, Android application ID `com.cglendenning.life_ops`.

This package contains the reviewed listing copy, reviewer notes, privacy/data
declaration working set, screenshot manifests and staged-release record.

Submission gate still requiring owner input: replace
`PUBLIC_PRIVACY_POLICY_URL_REQUIRED` with the final public HTTPS privacy-policy
URL. The app currently provides sign-out but no in-app account-deletion flow;
Google account-creation submission requirements therefore also need an owner
decision before D-182/D-183 can honestly be marked Done.

The screenshot capture runner is `scripts/capture_store_screenshots.sh`.
The latest physical-device attempt reached the paired iPhone but failed because
wireless Flutter VM access was unavailable on the local network. The checked-in
fallback images are the existing 1320x2868 Apple set, resized without cropping
to 1080x1920 for the Google phone set.
