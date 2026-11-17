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
'''.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((n) => ReleaseAsset(n, 'u/$n', 1)).toList();

  String? pick(Device d, Arch a, Variant v, Package p) => pickAsset(names, d, a, v, p)?.name;

  test('every device/variant/package resolves to the right file', () {
    expect(pick(Device.windows, Arch.x64, Variant.combined, Package.installer), 'Localview-Combined-windows-x64-setup.exe');
    expect(pick(Device.windows, Arch.x64, Variant.lan, Package.installer), 'Localview-LAN-windows-x64-setup.exe');
    expect(pick(Device.windows, Arch.x64, Variant.wan, Package.portable), 'Localview-WAN-windows-x64.zip');
    expect(pick(Device.macos, Arch.x64, Variant.combined, Package.installer), 'Localview-Combined-macos.dmg');
    expect(pick(Device.macos, Arch.arm64, Variant.combined, Package.portable), 'Localview-Combined-macos-universal.zip');
    expect(pick(Device.linux, Arch.x64, Variant.combined, Package.installer), 'localview-combined_1.0.0_amd64.deb');
    expect(pick(Device.linux, Arch.arm64, Variant.combined, Package.installer), 'localview-combined_1.0.0_arm64.deb');
    expect(pick(Device.linux, Arch.arm64, Variant.wan, Package.installer), 'localview-wan_1.0.0_arm64.deb');
    expect(pick(Device.linux, Arch.x64, Variant.combined, Package.portable), 'Localview-Combined-linux-x64.AppImage');
    expect(pick(Device.steamos, Arch.arm64, Variant.combined, Package.installer), 'Localview-Combined-steamos-arm64.AppImage');
    expect(pick(Device.steamos, Arch.arm64, Variant.lan, Package.installer), 'Localview-LAN-steamos-arm64.AppImage');
    expect(pick(Device.steamos, Arch.x64, Variant.combined, Package.portable), 'Localview-Combined-steamos-x64.tar.gz');
    expect(pick(Device.android, Arch.arm64, Variant.combined, Package.installer), 'Localview-Combined-android.apk');
    expect(pick(Device.androidTv, Arch.arm64, Variant.combined, Package.installer), 'Localview-Combined-android-tv.apk');
    expect(pick(Device.vr, Arch.arm64, Variant.wan, Package.installer), 'Localview-WAN-android-xr.apk');
    expect(pick(Device.ios, Arch.arm64, Variant.combined, Package.installer), 'Localview-Combined-ios-unsigned.ipa');
    // Missing combination -> null (e.g. no LAN Linux arm64 deb in this list).
    expect(pick(Device.linux, Arch.arm64, Variant.lan, Package.installer), isNull);
  });
}
