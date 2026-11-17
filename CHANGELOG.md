# Changelog

## 1.3.0

- **Android Pro**: new device choice for Localview Pro (Localview 1.9.0 and later), the Android app with a helper for real mouse and keyboard input when a computer controls the phone or tablet. Same processor choices as Android (per-processor APK, or the all-in-one APK as a fallback). It installs over the regular Android app and keeps its settings.

## 1.2.1

- **Android**: signed with the permanent release key, so later versions update over this one. Earlier Android builds used a temporary key: uninstall those once before installing this version.

## 1.2.1

- **Android**: the installer is now signed with the permanent release key, so later installer updates install over it. Earlier Android builds used a temporary key: uninstall those once before installing this version.

## 1.2.0

- **Version in every file name**: the installer's own downloads now end with their version (e.g. `LocalviewInstaller-windows-x64-1.2.0.zip`), like Localview's from 1.4.0 on.
- Finds Localview downloads under both the new versioned names and the older names, and recognises its own updates either way. Installer 1.1.1 and older only know the old names, so download this version once by hand.

## 1.1.1

- **iPhone / iPad**: the processor section now says *Apple silicon (ARM64)* and lists which iPhones and iPads are supported (iOS 15 or later).

## 1.1.0

- **Launch Localview**: after installing, a *Launch Localview* button starts the installed app (Windows, macOS, Linux, Android/TV/headsets).
- **Updates itself**: when a newer Localview Installer is released, a banner offers to download and install it.
- **Older and 32-bit Android devices**: pick ARMv7 (32-bit: older phones, most TVs, older headsets), ARM64 or x86-64 for Android, Android TV and VR headsets; detected automatically, with a hint for each.
- **Windows on ARM**: choose ARM64 for Snapdragon / Copilot+ PCs and Surface Pro X; the installer itself is also available for Windows ARM64.
- **Fedora/RHEL**: Linux offers the new `.rpm` package next to `.deb` and AppImage.

## 1.0.0

- Pick device, processor and Localview version; downloads the latest matching release and installs or opens it.
