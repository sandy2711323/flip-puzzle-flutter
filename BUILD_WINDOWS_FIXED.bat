@echo off
cd /d "%~dp0"

REM Creates missing Flutter platform folders/files if required.
flutter create .

REM Extra safety for newer Visual Studio/MSVC + audioplayers_windows.
set CL=/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS

flutter clean
flutter pub get
flutter build windows --release

pause
