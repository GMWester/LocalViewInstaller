# Localview Installer

A small app for every platform Localview supports that downloads the right [Localview](https://github.com/GMWester/Localview) build for you.

1. **Device** – Windows, macOS, Linux, SteamOS (Steam Frame / Steam Deck), Android, Android TV, VR headset (Meta Quest / Android XR) or iPhone/iPad. The device you're on is pre-selected.
2. **Processor** – x64 or ARM64 where both exist (Linux, SteamOS); detected automatically.
3. **Version** – **Combined** (recommended: LAN discovery + reach saved devices from anywhere), **LAN** or **WAN**.
4. **Package** – installer or portable, where both exist.

It looks up the latest Localview release on GitHub, downloads the matching file with progress, then installs or opens it on the current device (runs the Windows setup, opens the macOS disk image, starts the AppImage or opens the `.deb` in your software center, or launches the Android package installer). Files for another device are saved to your Downloads folder so you can copy them over. HTTP(S) proxies from the environment are respected.

## Download

Get it from [Releases](../../releases/latest): Windows `.zip`, macOS `.dmg`, Linux/SteamOS AppImage (x64 and ARM64), Android `.apk` (phones, TV, Quest, Android XR) and an unsigned iOS `.ipa`.

## Build

```bash
flutter pub get
flutter test
flutter build <windows|macos|linux|apk|ios>
```

`lib/catalog.dart` maps choices to release file names (covered by `test/catalog_test.dart`); `lib/main.dart` is the UI, downloader and installer launcher.

License: AGPL-3.0.
