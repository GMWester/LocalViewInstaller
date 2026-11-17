import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'catalog.dart';
import 'system.dart';

const String kRepo = 'GMWester/Localview';

void main() => runApp(const InstallerApp());

class InstallerApp extends StatelessWidget {
  const InstallerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F6FED);
    return MaterialApp(
      title: 'Localview Installer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.light, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: const InstallerPage(),
    );
  }
}

class Release {
  Release(this.tag, this.name, this.url, this.assets);
  final String tag, name, url;
  final List<ReleaseAsset> assets;
}

Future<Release> fetchLatestRelease() async {
  final client = newClient();
  try {
    final req = await client.getUrl(Uri.parse('https://api.github.com/repos/$kRepo/releases/latest'));
    req.headers.set('User-Agent', 'LocalviewInstaller');
    req.headers.set('Accept', 'application/vnd.github+json');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) throw HttpException('GitHub answered ${res.statusCode}');
    final j = jsonDecode(body) as Map<String, dynamic>;
    final assets = [
      for (final a in (j['assets'] as List).cast<Map<String, dynamic>>())
        ReleaseAsset(a['name'] as String, a['browser_download_url'] as String, a['size'] as int? ?? 0),
    ];
    return Release(j['tag_name'] as String? ?? '', j['name'] as String? ?? '', j['html_url'] as String? ?? '', assets);
  } finally {
    client.close();
  }
}

const _android = MethodChannel('localview_installer/android');

/// HTTP client that honours HTTP(S)_PROXY / NO_PROXY (corporate and school networks).
HttpClient newClient() => httpClient();

class InstallerPage extends StatefulWidget {
  const InstallerPage({super.key});
  @override
  State<InstallerPage> createState() => _InstallerPageState();
}

class _InstallerPageState extends State<InstallerPage> {
  final Device _thisDevice = detectDevice();
  late Device _device = _thisDevice;
  late Arch _arch = detectArch();
  Variant _variant = Variant.combined;
  Package _package = Package.installer;

  Release? _release;
  String? _loadError;
  bool _loading = true;

  double? _progress;
  String? _status;
  File? _downloaded;
  HttpClient? _activeDownload;
  String? _installedAt; // path/package of the installed Localview for the chosen version
  InstallerUpdate? _selfUpdate;
  double? _selfProgress;
  String? _selfMessage;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshInstalled();
    checkInstallerUpdate().then((u) {
      if (mounted && u != null) setState(() => _selfUpdate = u);
    });
  }

  Future<void> _refreshInstalled() async {
    final appImage = _downloaded?.path.endsWith('.AppImage') == true ? _downloaded!.path : null;
    final at = _forThisDevice ? await findInstalled(_variant, appImage: appImage) : null;
    if (mounted) setState(() => _installedAt = at);
  }

  Future<void> _launch() async {
    final at = _installedAt;
    if (at == null) return;
    try {
      await launchInstalled(at);
    } catch (e) {
      _snack('Could not start Localview: $e');
    }
  }

  Future<void> _updateSelf() async {
    final u = _selfUpdate;
    if (u == null || u.assetUrl == null) return;
    setState(() {
      _selfProgress = 0;
      _selfMessage = 'Downloading Localview Installer ${u.version}…';
    });
    try {
      final msg = await applyInstallerUpdate(u, (p) {
        if (mounted) setState(() => _selfProgress = p);
      });
      if (mounted) setState(() => _selfMessage = msg);
    } catch (e) {
      if (mounted) setState(() => _selfMessage = 'Update failed: $e');
    } finally {
      if (mounted) setState(() => _selfProgress = null);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final r = await fetchLatestRelease();
      if (mounted) setState(() => _release = r);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Could not reach GitHub: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ReleaseAsset? get _asset {
    final r = _release;
    if (r == null) return null;
    final arch = _device.arches.isEmpty ? _arch : (_device.arches.contains(_arch) ? _arch : _device.arches.first);
    final pkg = _device.packages.contains(_package) ? _package : _device.packages.first;
    return pickAsset(r.assets, _device, arch, _variant, pkg);
  }

  bool get _forThisDevice {
    final here = detectArch();
    final archOk = _device.arches.length < 2 ||
        _arch == here ||
        (_arch == Arch.armv7 && here == Arch.arm64 && Platform.isAndroid); // 64-bit phones run 32-bit apps
    return archOk && _forThisDeviceKind;
  }

  bool get _forThisDeviceKind =>
      _device == _thisDevice ||
      (_thisDevice == Device.android && (_device == Device.androidPro || _device == Device.androidTv || _device == Device.vr)) ||
      (_thisDevice == Device.linux && _device == Device.steamos) ||
      (_thisDevice == Device.steamos && _device == Device.linux);

  Future<Directory> _targetDir() async {
    Future<Directory?> attempt(Future<Directory?> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return null;
      }
    }

    if (Platform.isAndroid) {
      return await attempt(getExternalStorageDirectory) ?? await getApplicationDocumentsDirectory();
    }
    if (Platform.isIOS) return getApplicationDocumentsDirectory();
    final downloads = await attempt(getDownloadsDirectory);
    if (downloads != null) return downloads;
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) return Directory('$home${Platform.pathSeparator}Downloads');
    return await attempt(getApplicationDocumentsDirectory) ?? Directory.systemTemp;
  }

  String _size(int b) => b >= 1 << 20 ? '${(b / (1 << 20)).toStringAsFixed(1)} MB' : '${(b / 1024).toStringAsFixed(0)} KB';

  Future<void> _download() async {
    final a = _asset;
    if (a == null) return;
    setState(() {
      _progress = 0;
      _status = 'Downloading ${a.name}…';
      _downloaded = null;
    });
    final client = newClient();
    _activeDownload = client;
    File? part;
    try {
      final dir = await _targetDir();
      await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}${a.name}');
      part = File('${file.path}.part');
      final req = await client.getUrl(Uri.parse(a.url));
      req.headers.set('User-Agent', 'LocalviewInstaller');
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('download failed (${res.statusCode})');
      final total = res.contentLength > 0 ? res.contentLength : a.size;
      final sink = part.openWrite();
      var got = 0;
      var lastUi = DateTime.now();
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastUi).inMilliseconds > 100 && mounted) {
          lastUi = now;
          setState(() {
            _progress = total > 0 ? got / total : null;
            _status = 'Downloading ${a.name} · ${_size(got)}${total > 0 ? ' of ${_size(total)}' : ''}';
          });
        }
      }
      await sink.close();
      if (await file.exists()) await file.delete();
      await part.rename(file.path);
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _downloaded = file;
        _status = 'Saved to ${file.path}';
      });
    } catch (e) {
      try {
        if (part != null && await part.exists()) await part.delete();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _progress = null;
          _status = 'Download failed: $e';
        });
      }
    } finally {
      _activeDownload = null;
      client.close(force: true);
    }
  }

  void _cancel() {
    _activeDownload?.close(force: true);
  }

  Future<void> _install() async {
    final f = _downloaded;
    if (f == null) return;
    final p = f.path;
    // Watch for the installation to finish so the Launch button can appear.
    for (var i = 1; i <= 90; i++) {
      Future.delayed(Duration(seconds: i * 2), () {
        if (mounted && _installedAt == null) _refreshInstalled();
      });
    }
    try {
      if (Platform.isAndroid && p.endsWith('.apk')) {
        final ok = await _android.invokeMethod<bool>('install', {'path': p}) ?? false;
        if (!ok) _snack('Allow "Install unknown apps" for Localview Installer, then press Install again.');
      } else if (Platform.isWindows) {
        if (p.endsWith('.exe')) {
          await Process.start(p, const [], mode: ProcessStartMode.detached);
        } else {
          await Process.start('explorer.exe', ['/select,', p]);
        }
      } else if (Platform.isMacOS) {
        await Process.run('open', [p]);
      } else if (Platform.isLinux) {
        if (p.endsWith('.AppImage')) {
          await Process.run('chmod', ['+x', p]);
          await Process.start(p, const [], mode: ProcessStartMode.detached);
        } else if (p.endsWith('.deb')) {
          final r = await Process.run('xdg-open', [p]);
          if (r.exitCode != 0) _snack('Install it with: sudo apt install "$p"');
        } else {
          await Process.run('xdg-open', [f.parent.path]);
        }
      } else {
        _snack('Saved to ${f.path}');
      }
    } catch (e) {
      _snack('Could not open the file: $e');
    }
  }

  Future<void> _reveal() async {
    final f = _downloaded;
    if (f == null) return;
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,', f.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', f.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [f.parent.path]);
      } else {
        await Clipboard.setData(ClipboardData(text: f.path));
        _snack('Path copied: ${f.path}');
      }
    } catch (_) {}
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  IconData _icon(Device d) => switch (d) {
        Device.windows => Icons.desktop_windows,
        Device.macos => Icons.laptop_mac,
        Device.linux => Icons.terminal,
        Device.steamos => Icons.sports_esports,
        Device.android => Icons.phone_android,
        Device.androidPro => Icons.mouse,
        Device.androidTv => Icons.tv,
        Device.vr => Icons.view_in_ar,
        Device.ios => Icons.phone_iphone,
      };

  Widget _section(String step, String title, Widget child, {String? hint}) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 13, child: Text(step, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 10),
          Text(title, style: t.titleMedium),
        ]),
        if (hint != null) Padding(padding: const EdgeInsets.only(left: 36, top: 4), child: Text(hint, style: t.bodySmall)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _choice({required bool selected, required VoidCallback onTap, required Widget child, double width = 168}) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _progress != null && _progress! < 1 ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final asset = _asset;
    final busy = _progress != null && _progress! < 1;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.cast_connected), SizedBox(width: 10), Text('Localview Installer')]),
        actions: [
          if (_release != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(avatar: const Icon(Icons.new_releases_outlined, size: 18), label: Text(_release!.tag)),
            ),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
            Text('Get the right Localview for your device', style: t.headlineSmall),
            const SizedBox(height: 4),
            Text('Pick the device, its processor and the version. The latest release is downloaded straight from GitHub.',
                style: t.bodyMedium),
            const SizedBox(height: 22),
            if (_selfUpdate != null)
              Card(
                color: cs.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.system_update),
                      title: Text('Localview Installer ${_selfUpdate!.version} is available'),
                      subtitle: Text('You have $kInstallerVersion.'),
                      trailing: _selfUpdate!.assetUrl == null
                          ? null
                          : FilledButton(
                              onPressed: _selfProgress != null ? null : _updateSelf,
                              child: const Text('Update'),
                            ),
                    ),
                    if (_selfProgress != null) LinearProgressIndicator(value: _selfProgress),
                    if (_selfMessage != null) Text(_selfMessage!, style: t.bodySmall),
                  ]),
                ),
              ),
            if (_loading) const LinearProgressIndicator(),
            if (_loadError != null)
              Card(
                color: cs.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: Text(_loadError!),
                  trailing: TextButton(onPressed: _load, child: const Text('Retry')),
                ),
              ),
            _section(
              '1',
              'Device',
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final d in Device.values)
                  _choice(
                    selected: _device == d,
                    onTap: () {
                      setState(() {
                        _device = d;
                        _downloaded = null;
                        _status = null;
                        _progress = null;
                      });
                      _refreshInstalled();
                    },
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(_icon(d)),
                        const Spacer(),
                        if (d == _thisDevice) Text('this device', style: t.labelSmall?.copyWith(color: cs.primary)),
                      ]),
                      const SizedBox(height: 8),
                      Text(d.label, style: t.titleSmall),
                      Text(d.subtitle, style: t.bodySmall),
                    ]),
                  ),
              ]),
            ),
            _section(
              '2',
              'Processor',
              _device.arches.length > 1
                  ? SegmentedButton<Arch>(
                      showSelectedIcon: false,
                      segments: [for (final a in _device.arches) ButtonSegment(value: a, label: Text(a.label))],
                      selected: {_device.arches.contains(_arch) ? _arch : _device.arches.first},
                      onSelectionChanged: busy
                          ? null
                          : (v) {
                              setState(() => _arch = v.first);
                              _refreshInstalled();
                            },
                    )
                  : Text(
                      switch (_device) {
                        Device.macos => 'Universal: runs natively on Apple Silicon and Intel Macs.',
                        _ => 'Apple silicon (ARM64): every iPhone and iPad uses it.',
                      },
                      style: t.bodyMedium),
              hint: _device.archHint,
            ),
            _section(
              '3',
              'Version',
              Column(children: [
                for (final v in Variant.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _choice(
                      width: double.infinity,
                      selected: _variant == v,
                      onTap: () {
                        setState(() => _variant = v);
                        _refreshInstalled();
                      },
                      child: Row(children: [
                        Icon(_variant == v ? Icons.radio_button_checked : Icons.radio_button_off),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(v.label + (v == Variant.combined ? '  ·  recommended' : ''), style: t.titleSmall),
                            Text(v.description, style: t.bodySmall),
                          ]),
                        ),
                      ]),
                    ),
                  ),
              ]),
              hint: 'Devices must use the same version (LAN↔LAN, WAN↔WAN); Combined works with all of them.',
            ),
            if (_device.packages.length > 1)
              _section(
                '4',
                'Package',
                SegmentedButton<Package>(
                  segments: [for (final p in _device.packages) ButtonSegment(value: p, label: Text(_device.packageLabel(p)))],
                  selected: {_device.packages.contains(_package) ? _package : _device.packages.first},
                  onSelectionChanged: busy ? null : (v) => setState(() => _package = v.first),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_installedAt != null && _forThisDevice)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                        const SizedBox(width: 6),
                        Text('Localview ${_variant.label} is installed on this device', style: t.bodySmall),
                      ]),
                    ),
                  if (asset != null) ...[
                    Text(asset.name, style: t.titleSmall),
                    Text('${_size(asset.size)} · ${_release?.name ?? ''}', style: t.bodySmall),
                  ] else if (_release != null)
                    Text('This combination is not in the latest release.', style: t.bodyMedium)
                  else
                    Text('Waiting for the release list…', style: t.bodyMedium),
                  if (!_forThisDevice && asset != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('This file is for another device. It is saved to your downloads so you can copy it over.',
                          style: t.bodySmall?.copyWith(color: cs.tertiary)),
                    ),
                  const SizedBox(height: 14),
                  if (_progress != null) ...[
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 8),
                  ],
                  if (_status != null) Text(_status!, style: t.bodySmall),
                  const SizedBox(height: 12),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    if (busy)
                      OutlinedButton.icon(onPressed: _cancel, icon: const Icon(Icons.close), label: const Text('Cancel'))
                    else
                      FilledButton.icon(
                        onPressed: asset == null ? null : _download,
                        icon: const Icon(Icons.download),
                        label: Text(_downloaded == null ? 'Download' : 'Download again'),
                      ),
                    if (_downloaded != null && _forThisDevice && !Platform.isIOS)
                      FilledButton.tonalIcon(
                        onPressed: _install,
                        icon: const Icon(Icons.install_desktop),
                        label: Text(_downloaded!.path.endsWith('.zip') || _downloaded!.path.endsWith('.tar.gz')
                            ? 'Open'
                            : 'Install'),
                      ),
                    if (_installedAt != null && _forThisDevice)
                      FilledButton.icon(
                        onPressed: _launch,
                        icon: const Icon(Icons.play_arrow),
                        label: Text('Launch Localview ${_variant.label}'),
                      ),
                    if (_downloaded != null)
                      TextButton.icon(onPressed: _reveal, icon: const Icon(Icons.folder_open), label: const Text('Show file')),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
