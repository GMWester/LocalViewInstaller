# Localview Installer

A small app for every platform Localview supports that downloads the right [Localview](https://github.com/GMWester/Localview) build for you.

1. **Device** – Windows, macOS, Linux, SteamOS (Steam Frame / Steam Deck), Android, Android Pro (real mouse & keyboard when controlled), Android TV, VR headset (Meta Quest / Android XR) or iPhone/iPad. The device you're on is pre-selected.
2. **Processor** – detected automatically: x64 / ARM64 for Windows, Linux and SteamOS; ARMv7 (32-bit, older devices and most TVs) / ARM64 / x86-64 for Android, Android Pro, Android TV and VR headsets.
3. **Version** – **Combined** (recommended: LAN discovery + reach saved devices from anywhere), **LAN** or **WAN**.
4. **Package** – installer or portable where both exist (Linux: `.deb`, `.rpm` or AppImage).

After installing, **Launch Localview** starts it. When a newer Localview Installer is released, a banner offers to update the installer itself.

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
