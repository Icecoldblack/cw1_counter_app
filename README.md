# CW1 Counter & Toggle

CSC 4360 Mobile App Development, Coursework #01.
Author: Uyiosa Nehikhuere

A Flutter app with an interactive counter and an animated image toggle, with Light/Dark theme switching.

## Features

### Task 1: Counter
* Counter starts at 0 and is shown prominently. The **Increment** button adds the current step.
* **Multi-step controls:** a `SegmentedButton` picks +1, +5 or +10, and the current step is displayed.
* **Decrement + Reset:** both are disabled when the counter is 0, and decrement never goes below 0.
* **Goal meter:** set a target with **Set goal**. A progress bar tracks it and a SnackBar celebrates at 100%.
* **History + Undo:** the last five actions show as chips, and **Undo** reverts the most recent one.
* **State persistence:** counter, step, goal, image and theme are saved with `shared_preferences` and restored on launch.
* **Bonus:** the counter color shifts from green to red as it approaches the goal.

### Task 2: Image toggle & animation
* Two local assets (`assets/images/sun.png`, `assets/images/moon.png`) registered in `pubspec.yaml`.
* Tap the image or **Toggle Image** to switch between sun and moon.
* An `AnimationController` (500 ms) drives a `CurvedAnimation` (`easeInOut`) that powers two `FadeTransition`s (cross-fade) and a `RotationTransition`.
* The sun/moon icon in the app bar toggles the entire app between Light and Dark mode.

## Run

```bash
flutter pub get
flutter run
```

## Test and build

```bash
flutter analyze
flutter test
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

GitHub Actions (`.github/workflows/build.yml`) runs analyze, tests and the release build on every push, and uploads the APK as the `app-release-apk` artifact.
