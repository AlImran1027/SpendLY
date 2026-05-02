# Spendly

A Flutter expense tracker with receipt scanning and AI-powered data extraction.

## Features

- Receipt capture and AI extraction (Google Gemini or local LM Studio)
- SQLite expense storage with category budgets
- Analytics with custom bar and donut charts
- Firebase Authentication (email/password)
- Supports Android and iOS

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure Firebase

This project requires Firebase for authentication. The config files are **not** committed to this repo because they contain API keys.

**Steps:**

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add Android and iOS apps to the project (use package name `com.example.spendly`)
3. Install the FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
4. Run the configuration command from the project root:
   ```bash
   flutterfire configure
   ```
   This generates `lib/firebase_options.dart`, `android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist` automatically.

See `lib/firebase_options.dart.example` and `android/app/google-services.json.example` for the expected file structure.

### 3. Configure AI extraction (optional)

- **Gemini:** Add your API key in the app under Profile → Settings → Gemini AI API Key
- **LM Studio:** Run a local LM Studio server with a vision model, then add the URL under Profile → Settings → LM Studio

### 4. Run the app

```bash
flutter run
```

## Common Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter test             # Run all tests
flutter analyze          # Static analysis
flutter build apk        # Build Android APK
flutter build appbundle  # Build Play Store bundle
flutter clean            # Clean build artifacts
```

## Architecture

- **State management:** `StatefulWidget` + `SharedPreferences` (no external state library)
- **Database:** SQLite via `sqflite` — expenses, line items, and monthly budgets
- **Auth:** Firebase Authentication (email/password)
- **AI:** Google Gemini (`gemini-2.5-flash`) or LM Studio local inference (OpenAI-compatible API)
- **Navigation:** Named routes defined in `main.dart`; 4-tab bottom nav shell

## Environment / Secrets

The following files are git-ignored and must be generated locally:

| File | How to generate |
|------|----------------|
| `lib/firebase_options.dart` | `flutterfire configure` |
| `android/app/google-services.json` | `flutterfire configure` |
| `ios/Runner/GoogleService-Info.plist` | `flutterfire configure` |
| `firebase.json` | `flutterfire configure` |

Gemini API keys and LM Studio URLs are stored in `SharedPreferences` at runtime — they are never hardcoded or committed.
