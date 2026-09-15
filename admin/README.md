# Green Pyramid Admin

Private OTA-only administration client for D-165. This directory is a
separate Flutter app with bundle identifier `com.cglendenning.greenpyramid.admin`.

Before a device build, register that bundle identifier as a separate iOS app in
the `life-ops` Firebase project, enable Sign in with Apple for that app, and
run FlutterFire configuration from this directory. Set the operator's Firebase
custom claim with trusted server-side tooling:

```js
await admin.auth().setCustomUserClaims(uid, { admin: true });
```

The backend rejects every authenticated user without that claim. The app reads
`/adminMetrics` and submits simulation parameters to `/adminSimulation`; it
cannot mutate product data or select a project for simulation. The CLI uses the
same `/adminSimulation` endpoint and request shape. To run it against the
deployed service, provide an ID token for an account with the `admin: true`
custom claim:

```sh
FIREBASE_ID_TOKEN="<fresh Firebase ID token>" \
  node functions/bin/simulate-behavior.js \
  --months=6 --seed=1 --scenarios=autonomous,fatigue --failure-mode=default
```

Use `--endpoint=http://127.0.0.1:5001/<project>/us-central1/api/adminSimulation`
for a local Functions emulator. The endpoint always executes against the
server-defined sandbox target.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
