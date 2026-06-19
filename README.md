# Emoji Flip Puzzle

Updated version with:

- First-launch walkthrough for new users
- Help button to reopen the guide anytime
- How to play instructions
- Robot solver explanation
- Save/load game explanation
- Sound settings explanation
- Restart/change level explanation
- Background music and sound effects
- Robot stop confirmation
- Fireworks win celebration

## Run

```bash
flutter clean
flutter pub get
flutter run
```

## Build Android

```bash
flutter build apk --release
```

If Android Gradle project is unsupported after extracting ZIP, run this once inside the extracted folder:

```bash
flutter create .
flutter clean
flutter pub get
flutter build apk --release
```

## Windows build note

This ZIP includes a fixed `windows/CMakeLists.txt` with:

```cmake
add_definitions(-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)
```

This avoids the newer Visual Studio/MSVC `experimental/coroutine` error from the `audioplayers_windows` plugin.

Recommended Windows build:

```bat
flutter create .
flutter clean
flutter pub get
flutter build windows --release
```

Or double-click/run:

```bat
BUILD_WINDOWS_FIXED.bat
```
