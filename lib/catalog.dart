// Maps a user's choice (device, processor, variant, package type) to a file
// in the latest Localview release.
import 'dart:io';
import 'dart:ffi' show Abi;

enum Device { windows, macos, linux, steamos, android, androidTv, vr, ios }

enum Arch { x64, arm64, armv7 }

enum Variant { combined, lan, wan }

enum Package { installer, rpm, portable }

extension DeviceInfo on Device {
  String get label => switch (this) {
        Device.windows => 'Windows',
        Device.macos => 'macOS',
        Device.linux => 'Linux',
        Device.steamos => 'SteamOS',
        Device.android => 'Android',
        Device.androidTv => 'Android TV',
        Device.vr => 'VR headset',
        Device.ios => 'iPhone / iPad',
      };

  String get subtitle => switch (this) {
        Device.windows => 'Windows 10 / 11',
        Device.macos => 'Apple Silicon + Intel',
        Device.linux => 'Ubuntu, Fedora, Debian…',
        Device.steamos => 'Steam Frame, Steam Deck',
        Device.android => 'Phones & tablets, Android 7+',
        Device.androidTv => 'Google TV, Shield…',
        Device.vr => 'Meta Quest, Android XR',
        Device.ios => 'Sideload (AltStore…)',
      };

  /// Processor choices that exist for this device.
  List<Arch> get arches => switch (this) {
        Device.linux || Device.steamos => const [Arch.x64, Arch.arm64],
        Device.android || Device.androidTv => const [Arch.arm64, Arch.armv7, Arch.x64],
        Device.vr => const [Arch.arm64, Arch.armv7, Arch.x64],
        Device.windows => const [Arch.x64, Arch.arm64],
        _ => const [],
      };

  /// Help text shown under the processor choice.
  String? get archHint => switch (this) {
        Device.steamos => 'Steam Frame is ARM64, Steam Deck is x64.',
        Device.windows => 'ARM64 for Windows on ARM laptops (Snapdragon / Copilot+ PCs, Surface Pro X); x64 for everything else.',
        Device.android => 'ARM64 for phones from about 2017 on; ARMv7 for older or low-cost 32-bit phones; x86-64 for Chromebooks and emulators. Not sure? ARMv7 runs on almost every phone.',
        Device.androidTv => 'Most TVs and streaming sticks run 32-bit Android even with a 64-bit chip: pick ARMv7 if unsure. ARM64 for e.g. Shield TV and Google TV Streamer.',
        Device.vr => 'Quest 2/3/3S/Pro and Android XR headsets are ARM64. ARMv7 is for older 32-bit headsets on Android 10+; x86-64 for the Android XR emulator.',
        Device.ios => 'iPhones and iPads run on Apple silicon (A-series or M-series chips), which is ARM64, so there is one version for all of them. Needs iOS 15 or later: iPhone 6s / SE (1st gen) and newer, iPad Air 2, iPad mini 4, iPad (5th gen) and newer, every iPad Pro.',
        _ => null,
      };

  /// Package types available for this device.
  List<Package> get packages => switch (this) {
        Device.linux => const [Package.installer, Package.rpm, Package.portable],
        Device.windows || Device.macos || Device.steamos => const [Package.installer, Package.portable],
        _ => const [Package.installer],
      };

  String packageLabel(Package p) => switch ((this, p)) {
        (Device.windows, Package.installer) => 'Installer (.exe)',
        (Device.windows, Package.portable) => 'Portable (.zip)',
        (Device.macos, Package.installer) => 'Disk image (.dmg)',
        (Device.macos, Package.portable) => 'App (.zip)',
        (Device.linux, Package.installer) => 'Debian/Ubuntu (.deb)',
        (Device.linux, Package.rpm) => 'Fedora/RHEL (.rpm)',
        (Device.linux, Package.portable) => 'AppImage (any distro)',
        (Device.steamos, Package.installer) => 'AppImage',
        (Device.steamos, Package.portable) => 'Archive (.tar.gz)',
        (Device.ios, _) => 'Unsigned app (.ipa)',
        _ => 'App (.apk)',
      };
}

extension VariantInfo on Variant {
  String get label => switch (this) { Variant.combined => 'Combined', Variant.lan => 'LAN', Variant.wan => 'WAN' };
  String get description => switch (this) {
        Variant.combined => 'Nearby devices appear automatically, and devices you connect to once are saved so you can reach them from anywhere. Recommended.',
        Variant.lan => 'Only devices on the same router. Connect with the password set on the other device.',
        Variant.wan => 'Connect over the internet by IP address and password; devices are paired with a stored key.',
      };
}

extension ArchInfo on Arch {
  String get label => switch (this) { Arch.x64 => 'x64 (Intel / AMD)', Arch.arm64 => 'ARM64', Arch.armv7 => 'ARMv7 (32-bit)' };

  /// Suffix of the per-processor Android APKs.
  String get apkSuffix => switch (this) { Arch.x64 => 'x86_64', Arch.arm64 => 'arm64', Arch.armv7 => 'armv7' };
}

/// Patterns a release asset may match, best first (per-processor APK before the all-in-one APK).
List<RegExp> assetPatterns(Device d, Arch a, Variant v, Package p) {
  final apk = switch (d) { Device.android => 'android', Device.androidTv => 'android-tv', Device.vr => 'android-xr', _ => null };
  if (apk != null) {
    final e = RegExp.escape;
    return [
      RegExp('^${e('Localview-${v.label}-$apk-${a.apkSuffix}.apk')}\$'),
      RegExp('^${e('Localview-${v.label}-$apk.apk')}\$'),
    ];
  }
  return [
    assetPattern(d, a, v, p),
    // Windows on ARM runs the x64 build too (emulated) when there is no ARM64 file.
    if (d == Device.windows && a == Arch.arm64) assetPattern(d, Arch.x64, v, p),
  ];
}

/// The pattern a release asset must match.
RegExp assetPattern(Device d, Arch a, Variant v, Package p) {
  final label = v.label; // LAN / WAN / Combined
  final mode = v.name; // lan / wan / combined
  final arch = a == Arch.arm64 ? 'arm64' : 'x64';
  final debArch = a == Arch.arm64 ? 'arm64' : 'amd64';
  String e(String s) => RegExp.escape(s);
  final pattern = switch ((d, p)) {
    (Device.windows, Package.installer) => '^${e('Localview-$label-windows-$arch-setup.exe')}\$',
    (Device.windows, Package.portable) => '^${e('Localview-$label-windows-$arch.zip')}\$',
    (Device.macos, Package.installer) => '^${e('Localview-$label-macos.dmg')}\$',
    (Device.macos, Package.portable) => '^${e('Localview-$label-macos-universal.zip')}\$',
    (Device.linux, Package.installer) => '^${e('localview-${mode}_')}.+_${e('$debArch.deb')}\$',
    (Device.linux, Package.rpm) => '^${e('localview-$mode-')}.+\\.${a == Arch.arm64 ? 'aarch64' : 'x86_64'}\\.rpm\$',
    (_, Package.rpm) => r'^$ no rpm for this device',
    (Device.linux, Package.portable) => '^${e('Localview-$label-linux-$arch.AppImage')}\$',
    (Device.steamos, Package.installer) => '^${e('Localview-$label-steamos-$arch.AppImage')}\$',
    (Device.steamos, Package.portable) => '^${e('Localview-$label-steamos-$arch.tar.gz')}\$',
    (Device.android, _) => '^${e('Localview-$label-android.apk')}\$',
    (Device.androidTv, _) => '^${e('Localview-$label-android-tv.apk')}\$',
    (Device.vr, _) => '^${e('Localview-$label-android-xr.apk')}\$',
    (Device.ios, _) => '^${e('Localview-$label-ios-unsigned.ipa')}\$',
  };
  return RegExp(pattern);
}

class ReleaseAsset {
  ReleaseAsset(this.name, this.url, this.size);
  final String name, url;
  final int size;
}

ReleaseAsset? pickAsset(List<ReleaseAsset> assets, Device d, Arch a, Variant v, Package p) {
  for (final re in assetPatterns(d, a, v, p)) {
    for (final x in assets) {
      if (re.hasMatch(x.name)) return x;
    }
  }
  return null;
}

/// Best guess for the device this installer runs on.
Device detectDevice() {
  if (Platform.isWindows) return Device.windows;
  if (Platform.isMacOS) return Device.macos;
  if (Platform.isIOS) return Device.ios;
  if (Platform.isAndroid) return Device.android;
  if (Platform.isLinux) {
    try {
      final os = File('/etc/os-release').readAsStringSync().toLowerCase();
      if (os.contains('steamos')) return Device.steamos;
    } catch (_) {}
    return Device.linux;
  }
  return Device.windows;
}

Arch detectArch() {
  final abi = Abi.current();
  if (abi == Abi.androidArm) return Arch.armv7;
  if (abi == Abi.androidX64) return Arch.x64;
  return (abi == Abi.linuxArm64 || abi == Abi.macosArm64 || abi == Abi.windowsArm64 || abi == Abi.androidArm64)
      ? Arch.arm64
      : Arch.x64;
}
