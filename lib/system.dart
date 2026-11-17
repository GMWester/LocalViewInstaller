// Finding/launching an installed Localview, and updating this installer itself.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'catalog.dart';

const String kInstallerVersion = String.fromEnvironment('LI_VERSION', defaultValue: '1.2.1');
const String kInstallerRepo = 'GMWester/LocalViewInstaller';

const _android = MethodChannel('localview_installer/android');

HttpClient httpClient() => HttpClient()
  ..connectionTimeout = const Duration(seconds: 20)
  ..findProxy = HttpClient.findProxyFromEnvironment;

String androidPackage(Variant v) => 'io.localview.localview.${v.name}';

/// Where Localview [v] is installed on this computer, or null. On Android the
/// package name is returned. [appImage] is a just-downloaded AppImage, if any.
Future<String?> findInstalled(Variant v, {String? appImage}) async {
  try {
    if (Platform.isAndroid) {
      final ok = await _android.invokeMethod<bool>('isInstalled', {'package': androidPackage(v)}) ?? false;
      return ok ? androidPackage(v) : null;
    }
    if (Platform.isWindows) {
      for (final base in {Platform.environment['ProgramW6432'], Platform.environment['ProgramFiles']}) {
        if (base == null) continue;
        final exe = '$base\\Localview ${v.label}\\Localview ${v.label}.exe';
        if (File(exe).existsSync()) return exe;
      }
    }
    if (Platform.isMacOS) {
      for (final dir in ['/Applications', '${Platform.environment['HOME']}/Applications']) {
        final app = '$dir/Localview ${v.label}.app';
        if (Directory(app).existsSync()) return app;
      }
    }
    if (Platform.isLinux) {
      final opt = '/opt/localview-${v.name}/localview';
      if (File(opt).existsSync()) return opt;
      if (appImage != null && File(appImage).existsSync()) return appImage;
    }
  } catch (_) {}
  return null;
}

Future<void> launchInstalled(String where) async {
  if (Platform.isAndroid) {
    await _android.invokeMethod('launch', {'package': where});
  } else if (Platform.isMacOS) {
    await Process.run('open', [where]);
  } else {
    if (where.endsWith('.AppImage')) await Process.run('chmod', ['+x', where]);
    await Process.start(where, const [], mode: ProcessStartMode.detached);
  }
}

// ------------------------------------------------------------------ self-update

class InstallerUpdate {
  InstallerUpdate(this.version, this.assetName, this.assetUrl);
  final String version;
  final String? assetName, assetUrl;
}

int compareVersions(String a, String b) {
  List<int> p(String v) => v.replaceFirst(RegExp(r'^v'), '').split(RegExp(r'[.+-]')).map((x) => int.tryParse(x) ?? 0).toList();
  final x = p(a), y = p(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// This installer's release file: `LocalviewInstaller-<platform>-<version><ext>` from 1.2.0 on,
/// without the version before that.
RegExp? selfAssetPattern() {
  final arch = detectArch() == Arch.arm64 ? 'arm64' : 'x64';
  RegExp named(String stem, String ext) =>
      RegExp('^${RegExp.escape(stem)}(-[0-9]+(\\.[0-9]+)*)?${RegExp.escape(ext)}\$');
  if (Platform.isWindows) return named('LocalviewInstaller-windows-$arch', '.zip');
  if (Platform.isMacOS) return named('LocalviewInstaller-macos', '.dmg');
  if (Platform.isAndroid) return named('LocalviewInstaller-android', '.apk');
  if (Platform.isLinux) {
    return (Platform.environment['APPIMAGE'] ?? '').isNotEmpty
        ? named('LocalviewInstaller-linux-$arch', '.AppImage')
        : named('LocalviewInstaller-linux-$arch', '.tar.gz');
  }
  return null;
}

/// Returns the newer installer release, or null when this one is current.
Future<InstallerUpdate?> checkInstallerUpdate() async {
  final c = httpClient();
  try {
    final req = await c.getUrl(Uri.parse('https://api.github.com/repos/$kInstallerRepo/releases/latest'));
    req.headers.set('User-Agent', 'LocalviewInstaller/$kInstallerVersion');
    req.headers.set('Accept', 'application/vnd.github+json');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) return null;
    final j = jsonDecode(body) as Map<String, dynamic>;
    final version = (j['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
    if (compareVersions(version, kInstallerVersion) <= 0) return null;
    final want = selfAssetPattern();
    for (final a in (j['assets'] as List).cast<Map<String, dynamic>>()) {
      final name = a['name'] as String;
      if (want != null && want.hasMatch(name)) return InstallerUpdate(version, name, a['browser_download_url'] as String);
    }
    return InstallerUpdate(version, null, null);
  } catch (_) {
    return null;
  } finally {
    c.close();
  }
}

/// Downloads and applies the installer update. Returns a message, or exits
/// (after starting the new version) when it can replace itself.
Future<String> applyInstallerUpdate(InstallerUpdate u, void Function(double) progress) async {
  final dir = Platform.isAndroid ? (await getExternalStorageDirectory())! : await getTemporaryDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}${u.assetName}');
  final c = httpClient();
  try {
    final req = await c.getUrl(Uri.parse(u.assetUrl!));
    req.headers.set('User-Agent', 'LocalviewInstaller/$kInstallerVersion');
    final res = await req.close();
    if (res.statusCode != 200) throw HttpException('download failed (${res.statusCode})');
    final total = res.contentLength;
    final sink = file.openWrite();
    var got = 0;
    await for (final chunk in res) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) progress(got / total);
    }
    await sink.close();
  } finally {
    c.close(force: true);
  }
  final p = file.path;
  if (Platform.isAndroid) {
    final ok = await _android.invokeMethod<bool>('install', {'path': p}) ?? false;
    return ok ? 'Confirm the update in the Android installer.' : 'Allow "Install unknown apps" for Localview Installer, then try again.';
  }
  if (Platform.isMacOS) {
    await Process.run('open', [p]);
    return 'Drag the new Localview Installer into Applications to replace this one.';
  }
  if (Platform.isWindows) {
    // Unpack next to the current copy and start the new version.
    final current = File(Platform.resolvedExecutable).parent;
    final target = '${current.parent.path}\\LocalviewInstaller-${u.version}';
    final r = await Process.run('powershell', ['-NoProfile', '-Command', 'Expand-Archive -Force -Path "$p" -DestinationPath "$target"']);
    if (r.exitCode != 0) return 'Could not unpack the update: ${r.stderr}';
    final exe = Directory(target).listSync(recursive: true).whereType<File>().firstWhere(
          (f) => f.path.endsWith('Localview Installer.exe'),
          orElse: () => File(''),
        );
    if (exe.path.isEmpty) return 'Update unpacked to $target.';
    await Process.start(exe.path, const [], mode: ProcessStartMode.detached);
    exit(0);
  }
  if (Platform.isLinux) {
    final appImage = Platform.environment['APPIMAGE'] ?? '';
    if (appImage.isNotEmpty) {
      await Process.run('chmod', ['+x', p]);
      await file.copy('$appImage.new');
      await File('$appImage.new').rename(appImage);
      await Process.start(appImage, const [], mode: ProcessStartMode.detached);
      exit(0);
    }
    final dest = File(Platform.resolvedExecutable).parent.path;
    final r = await Process.run('tar', ['xzf', p, '--strip-components=1', '-C', dest]);
    if (r.exitCode != 0) return 'Could not unpack the update: ${r.stderr}';
    await Process.start(Platform.resolvedExecutable, const [], mode: ProcessStartMode.detached);
    exit(0);
  }
  return 'Saved to $p';
}
