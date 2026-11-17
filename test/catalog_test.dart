import 'package:flutter_test/flutter_test.dart';
import 'package:localview_installer/catalog.dart';

void main() {
  // Asset names exactly as published in the Localview v1.0.0 release.
  final names = '''
Localview-Combined-android-tv.apk Localview-Combined-android-xr.apk Localview-Combined-android.apk
Localview-Combined-ios-unsigned.ipa Localview-Combined-linux-arm64.AppImage Localview-Combined-linux-arm64.tar.gz
Localview-Combined-linux-x64.AppImage Localview-Combined-linux-x64.tar.gz Localview-Combined-macos-universal.zip
Localview-Combined-macos.dmg Localview-Combined-steamos-arm64.AppImage Localview-Combined-steamos-arm64.tar.gz
Localview-Combined-steamos-x64.AppImage Localview-Combined-steamos-x64.tar.gz Localview-Combined-windows-x64-setup.exe
Localview-Combined-windows-x64.zip Localview-LAN-windows-x64-setup.exe Localview-WAN-windows-x64.zip
localview-combined_1.0.0_amd64.deb localview-combined_1.0.0_arm64.deb localview-lan_1.0.0_amd64.deb
localview-wan_1.0.0_arm64.deb Localview-WAN-android-xr.apk Localview-LAN-steamos-arm64.AppImage
Localview-Combined-android-armv7.apk Localview-Combined-android-arm64.apk Localview-Combined-android-tv-armv7.apk
Localview-Combined-android-xr-arm64.apk Localview-Combined-windows-arm64-setup.exe localview-combined-1.2.0-1.x86_64.rpm localview-combined-1.2.0-1.aarch64.rpm
'''.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((n) => ReleaseAsset(n, 'u/$n', 1)).toList();

  String? pick(Device d, Arch a, Variant v, Package p) => pickAsset(names, d, a, v, p)?.name;

  test('Localview 1.4.0+ file names (version at the end) are found too', () {
    final v14 = '''
Localview-Combined-windows-x64-setup-1.4.0.exe Localview-Combined-windows-arm64-1.4.0.zip Localview-Combined-macos-1.4.0.dmg
Localview-Combined-macos-universal-1.4.0.zip Localview-Combined-linux-x64-1.4.0.AppImage Localview-Combined-steamos-x64-1.4.0.tar.gz
Localview-Combined-android-1.4.0.apk Localview-Combined-android-arm64-1.4.0.apk Localview-Combined-android-tv-armv7-1.4.0.apk
Localview-Combined-android-xr-1.4.0.apk Localview-Combined-ios-unsigned-1.4.0.ipa localview-combined_1.4.0_amd64.deb
localview-combined-1.4.0-1.x86_64.rpm
'''.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((n) => ReleaseAsset(n, 'u/$n', 1)).toList();
    String? p14(Device d, Arch a, Package p) => pickAsset(v14, d, a, Variant.combined, p)?.name;
    expect(p14(Device.windows, Arch.x64, Package.installer), 'Localview-Combined-windows-x64-setup-1.4.0.exe');
    expect(p14(Device.windows, Arch.arm64, Package.portable), 'Localview-Combined-windows-arm64-1.4.0.zip');
    expect(p14(Device.macos, Arch.arm64, Package.installer), 'Localview-Combined-macos-1.4.0.dmg');
    expect(p14(Device.macos, Arch.arm64, Package.portable), 'Localview-Combined-macos-universal-1.4.0.zip');
    expect(p14(Device.linux, Arch.x64, Package.portable), 'Localview-Combined-linux-x64-1.4.0.AppImage');
    expect(p14(Device.linux, Arch.x64, Package.installer), 'localview-combined_1.4.0_amd64.deb');
    expect(p14(Device.linux, Arch.x64, Package.rpm), 'localview-combined-1.4.0-1.x86_64.rpm');
    expect(p14(Device.steamos, Arch.x64, Package.portable), 'Localview-Combined-steamos-x64-1.4.0.tar.gz');
    expect(p14(Device.android, Arch.arm64, Package.installer), 'Localview-Combined-android-arm64-1.4.0.apk');
    expect(p14(Device.android, Arch.armv7, Package.installer), 'Localview-Combined-android-1.4.0.apk');
    expect(p14(Device.androidTv, Arch.armv7, Package.installer), 'Localview-Combined-android-tv-armv7-1.4.0.apk');
    expect(p14(Device.vr, Arch.arm64, Package.installer), 'Localview-Combined-android-xr-1.4.0.apk');
    expect(p14(Device.ios, Arch.arm64, Package.installer), 'Localview-Combined-ios-unsigned-1.4.0.ipa');
  });

  test('every device/variant/package resolves to the right file', () {
    expect(pick(Device.windows, Arch.x64, Variant.combined, Package.installer), 'Localview-Combined-windows-x64-setup.exe');
    expect(pick(Device.windows, Arch.x64, Variant.lan, Package.installer), 'Localview-LAN-windows-x64-setup.exe');
    expect(pick(Device.windows, Arch.x64, Variant.wan, Package.portable), 'Localview-WAN-windows-x64.zip');
    expect(pick(Device.windows, Arch.arm64, Variant.combined, Package.installer), 'Localview-Combined-windows-arm64-setup.exe');
    // Older releases without ARM64 files fall back to x64 (emulated).
    expect(pick(Device.windows, Arch.arm64, Variant.lan, Package.installer), 'Localview-LAN-windows-x64-setup.exe');
    expect(pick(Device.macos, Arch.x64, Variant.combined, Package.installer), 'Localview-Combined-macos.dmg');
    expect(pick(Device.macos, Arch.arm64, Variant.combined, Package.portable), 'Localview-Combined-macos-universal.zip');
    expect(pick(Device.linux, Arch.x64, Variant.combined, Package.installer), 'localview-combined_1.0.0_amd64.deb');
    expect(pick(Device.linux, Arch.arm64, Variant.combined, Package.installer), 'localview-combined_1.0.0_arm64.deb');
    expect(pick(Device.linux, Arch.arm64, Variant.wan, Package.installer), 'localview-wan_1.0.0_arm64.deb');
    expect(pick(Device.linux, Arch.x64, Variant.combined, Package.portable), 'Localview-Combined-linux-x64.AppImage');
    expect(pick(Device.steamos, Arch.arm64, Variant.combined, Package.installer), 'Localview-Combined-steamos-arm64.AppImage');
    expect(pick(Device.steamos, Arch.arm64, Variant.lan, Package.installer), 'Localview-LAN-steamos-arm64.AppImage');
    expect(pick(Device.steamos, Arch.x64, Variant.combined, Package.portable), 'Localview-Combined-steamos-x64.tar.gz');
    expect(pick(Device.android, Arch.arm64, Variant.combined, Package.installer), 'Localview-Combined-android-arm64.apk');
    expect(pick(Device.android, Arch.armv7, Variant.combined, Package.installer), 'Localview-Combined-android-armv7.apk');
    // No per-processor file -> the all-in-one APK.
    expect(pick(Device.android, Arch.x64, Variant.combined, Package.installer), 'Localview-Combined-android.apk');
    expect(pick(Device.androidTv, Arch.armv7, Variant.combined, Package.installer), 'Localview-Combined-android-tv-armv7.apk');
    expect(pick(Device.vr, Arch.arm64, Variant.combined, Package.installer), 'Localview-Combined-android-xr-arm64.apk');
    expect(pick(Device.linux, Arch.x64, Variant.combined, Package.rpm), 'localview-combined-1.2.0-1.x86_64.rpm');
    expect(pick(Device.linux, Arch.arm64, Variant.combined, Package.rpm), 'localview-combined-1.2.0-1.aarch64.rpm');
    expect(pick(Device.linux, Arch.x64, Variant.lan, Package.rpm), isNull);
    expect(pick(Device.androidTv, Arch.arm64, Variant.combined, Package.installer), 'Localview-Combined-android-tv.apk');
    expect(pick(Device.vr, Arch.arm64, Variant.wan, Package.installer), 'Localview-WAN-android-xr.apk');
    expect(pick(Device.ios, Arch.arm64, Variant.combined, Package.installer), 'Localview-Combined-ios-unsigned.ipa');
    // Missing combination -> null (e.g. no LAN Linux arm64 deb in this list).
    expect(pick(Device.linux, Arch.arm64, Variant.lan, Package.installer), isNull);
  });
}
