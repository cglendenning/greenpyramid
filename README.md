# Green Pyramid

Green Pyramid is an AI-empowered system designed to make it effortless to live your best possible life. The methodology is built on the principle that foundational habits have exponentially greater impact on your life than non-foundational ones. Think of it like a real pyramid—if the foundation is weak, the whole structure crumbles. The same applies to your life.

## The Green Pyramid Methodology

- **Hierarchical Habit Tracking:** The pyramid has 6 levels, with your most important values at the bottom (foundational) and less critical ones at the top. Categories 1, 2, and 3 are your foundational values—the bedrock of life success and well-being. Gaps in these foundational habits carry significantly more weight than gaps in higher categories.
- **Personalized Values and Actions:** You choose your 6 most important life values or categories. For each, you define specific daily tasks or habits. These are not random tasks, but carefully chosen actions that align with your core values and move you toward your best life.
- **Daily Action and Review:** Each value requires daily action if you are truly committed to it. You receive three notifications per day (morning, afternoon, evening) to check in on your tasks. Mark tasks as completed or not completed; your pyramid colors update based on your completion percentage for each category.
- **Color-Coded Feedback:**
  - **Green:** Crushing most or all of your habits toward your best life
  - **Yellow:** Executing some of your habits
  - **Red:** Doing few or none of your habits
  The goal is to keep your pyramid as green as possible, especially the foundational levels.
- **AI Coaching:** The Coach feature is an AI-powered life coach that analyzes your habit tracking data and provides personalized insights. It prioritizes foundational habit gaps while acknowledging progress in all areas, offering specific, actionable guidance.
- **Progress and Adaptation:** The system tracks your completion percentage over time, so occasional missed days won't drastically affect your overall progress. The key is consistency over the long term. You can edit your categories and tasks at any time as your life evolves.
- **Visual and Motivational:** The visual pyramid makes it easy to see your life balance at a glance. The methodology encourages you to focus on what matters most, build a solid foundation, and use daily actions to move toward your best self.

---

## Features

- **Personalized Task Management:** Organize daily tasks by value-driven categories.
- **Morning, Afternoon, and Evening Flows:** Custom motivational and summary screens for each part of the day.
- **Progress Tracking:** Visualize your progress and completed tasks.
- **Coaching & Motivation:** Integrated AI-powered coaching and motivational feedback.
- **Subscription & Paywall:** RevenueCat integration for premium features.
- **Push Notifications:** Timely reminders and motivational quotes.
- **Onboarding & Tutorials:** Guided setup and onboarding flows.
- **Multi-platform:** Runs on iOS, Android, and Web.

## Project Structure

```
lib/
  main.dart                # App entry point
  db.dart                  # Local SQLite database helper
  firebase_options.dart    # Firebase config (uses secrets.dart)
  secrets.dart             # API keys and secrets (not in version control)
  morning.dart, afternoon.dart, evening.dart  # Main daily flows
  progress.dart, pyramid.dart, profile.dart   # Progress and user profile
  paywall.dart, subscription_status.dart      # Subscription management
  setup/                   # Onboarding and setup screens
  tutorial/                # Tutorial and onboarding flows
  graveyard/               # Deprecated/experimental code (excluded from builds)
  ...                      # Other feature files
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [CocoaPods](https://guides.cocoapods.org/using/getting-started.html) (for iOS)
- [Android Studio](https://developer.android.com/studio) (for Android)

### Setup

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd life_ops
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure secrets:**
   - Copy `lib/secrets.dart.example` to `lib/secrets.dart` (if provided), or create your own:
     ```dart
     // lib/secrets.dart
     const String openAIApiKey = 'YOUR_OPENAI_API_KEY';
     const String revenuecatAndroidKey = 'YOUR_REVENUECAT_ANDROID_KEY';
     const String revenuecatIOSKey = 'YOUR_REVENUECAT_IOS_KEY';
     // ...Firebase keys as in the codebase...
     ```
   - **Do not commit `lib/secrets.dart`** (it's in `.gitignore`).

4. **Platform-specific setup:**
   - **iOS:**  
     - Ensure you have a valid `ios/Runner/GoogleService-Info.plist` for Firebase.
     - Run:
       ```bash
       cd ios
       pod install
       cd ..
       ```
   - **Android:**  
     - Ensure you have a valid `android/app/google-services.json` for Firebase.

5. **Build and run:**
   - For iOS:
     ```bash
     flutter build ios --release
     ```
   - For Android:
     ```bash
     flutter build appbundle --release
     ```
   - For Web:
     ```bash
     flutter build web
     ```

## Database

- Uses SQLite via the `sqflite` package.
- Tables: `task`, `tasklog`, `category`, `quote`, `chat_messages`, `vision_statement`.
- No manual setup required; tables are created automatically.

## Assets

- Images, SVGs, and videos are in the `images/` and `videos/` directories.
- Fonts are in the `fonts/` directory and configured in `pubspec.yaml`.

## Excluded Code

- The `lib/graveyard/` directory contains deprecated or experimental code and is excluded from builds via `build.yaml`.

## Security

- All API keys and secrets are stored in `lib/secrets.dart` (not committed).
- Native Firebase config files (`GoogleService-Info.plist`, `google-services.json`) are required for platform builds and should be kept private.

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License

MIT License

> **Note:** All actual content of YouTube videos referenced or embedded in this app is proprietary and subject to the copyright and terms of the original creators. The Green Pyramid hierarchical habit tracking method is proprietary and may not be distributed or repackaged for commercial use without explicit permission.
