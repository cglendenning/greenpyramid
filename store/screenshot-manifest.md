# Screenshot manifest

## Apple

The Apple set contains five portrait screenshots, each 1320x2868 pixels, and is
within the 1–10 screenshot upload limit for a supported iPhone size class.

| File | Story |
|---|---|
| `screenshots/apple/01-home-pyramid.png` | Personal pyramid overview |
| `screenshots/apple/02-morning-tasks.png` | Morning check-in |
| `screenshots/apple/03-evening-tasks.png` | Evening review |
| `screenshots/apple/04-analysis.png` | Analysis journey |
| `screenshots/apple/05-coach.png` | Coach / reflective guidance |

## Google Play phone

The phone set contains five portrait screenshots, each 1080x1920 pixels. It is
within the phone-set limit and uses the same English copy/story order as Apple.

## Apple iPad / large screen

The current-build iPad simulator set contains six portrait screenshots at
1640x2360 pixels. They are the six Analysis journey stories, captured from the
release code path with seeded local demo data and no debug banner or overlay.

| File | Story | Alt text |
|---|---|---|
| `screenshots/apple-ipad/01-analysis-showing-up.png` | Showing up | Six-page Analysis journey showing completed check-ins |
| `screenshots/apple-ipad/02-analysis-strength.png` | Strength | Analysis page describing the strongest area |
| `screenshots/apple-ipad/03-analysis-rhythm.png` | Rhythm | Analysis page describing recent rhythm |
| `screenshots/apple-ipad/04-analysis-return.png` | Return | Analysis page describing returning activity |
| `screenshots/apple-ipad/05-analysis-care.png` | Gentle care | Analysis page showing one gentle opportunity |
| `screenshots/apple-ipad/06-analysis-close.png` | Takeaway | Analysis closing page with a practical takeaway |

## Accuracy note

The phone artwork is the repository's existing current-dimension set. The
iPad Analysis set was captured on the current build using the iPad (A16)
simulator after a gesture-settle pass; the physical iPad release smoke check
separately verified the same app at 1536x2048. The capture runner remains at
`scripts/capture_store_screenshots.sh`; it requires local-network access only
when pointed at a physical device.

The Google phone set is complete. This release package targets the Google Play
phone form factor; no Android tablet/large-screen upload set is claimed in the
submission record. The Apple iPad set is included because the Apple binary is
configured and reviewed for iPad.
