// Maps a user's choice (device, processor, variant, package type) to a file
// in the latest Localview release.
import 'dart:io';
import 'dart:ffi' show Abi;

enum Device { windows, macos, linux, steamos, android, androidTv, vr, ios }

enum Arch { x64, arm64 }

enum Variant { combined, lan, wan }

enum Package { installer, portable }

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
        Device.android => 'Phones & tablets',
        Device.androidTv => 'Google TV, Shield…',
        Device.vr => 'Meta Quest, Android XR',
        Device.ios => 'Sideload (AltStore…)',
      };

  /// Processor choices that exist for this device.
  List<Arch> get arches => switch (this) {
        Device.linux || Device.steamos => const [Arch.x64, Arch.arm64],
        Device.windows => const [Arch.x64],
        _ => const [],
      };

  /// Package types available for this device.
  List<Package> get packages => switch (this) {
        Device.windows || Device.macos || Device.linux || Device.steamos => const [Package.installer, Package.portable],
        _ => const [Package.installer],
      };

  String packageLabel(Package p) => switch ((this, p)) {
        (Device.windows, Package.installer) => 'Installer (.exe)',
        (Device.windows, Package.portable) => 'Portable (.zip)',
        (Device.macos, Package.installer) => 'Disk image (.dmg)',
        (Device.macos, Package.portable) => 'App (.zip)',
        (Device.linux, Package.installer) => 'Debian/Ubuntu package (.deb)',
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
  String get label => switch (this) { Arch.x64 => 'x64 (Intel / AMD)', Arch.arm64 => 'ARM64' };
}

/// The pattern a release asset must match.
RegExp assetPattern(Device d, Arch a, Variant v, Package p) {
  final label = v.label; // LAN / WAN / Combined
  final mode = v.name; // lan / wan / combined
  final arch = a == Arch.arm64 ? 'arm64' : 'x64';
  final debArch = a == Arch.arm64 ? 'arm64' : 'amd64';
  String e(String s) => RegExp.escape(s);
  final pattern = switch ((d, p)) {
    (Device.windows, Package.installer) => '^${e('Localview-$label-windows-x64-setup.exe')}\$',
    (Device.windows, Package.portable) => '^${e('Localview-$label-windows-x64.zip')}\$',
    (Device.macos, Package.installer) => '^${e('Localview-$label-macos.dmg')}\$',
    (Device.macos, Package.portable) => '^${e('Localview-$label-macos-universal.zip')}\$',
    (Device.linux, Package.installer) => '^${e('localview-${mode}_')}.+_${e('$debArch.deb')}\$',
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
  final re = assetPattern(d, a, v, p);
  for (final x in assets) {
    if (re.hasMatch(x.name)) return x;
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
  return (abi == Abi.linuxArm64 || abi == Abi.macosArm64 || abi == Abi.windowsArm64 || abi == Abi.androidArm64)
      ? Arch.arm64
      : Arch.x64;
}
