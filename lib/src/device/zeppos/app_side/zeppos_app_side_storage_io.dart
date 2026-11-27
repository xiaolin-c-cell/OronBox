import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'zeppos_app_side_storage.dart';

ZeppOsAppSideStorage createZeppOsAppSideStorage() => _IoZeppOsAppSideStorage();

class _IoZeppOsAppSideStorage implements ZeppOsAppSideStorage {
  Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}zeppos'
      '${Platform.pathSeparator}apps',
    );
  }

  String _id(int appId) => appId.toRadixString(16).padLeft(8, '0');

  Future<Directory> _app(int appId) async => Directory(
    '${(await _root()).path}${Platform.pathSeparator}${_id(appId)}',
  );

  Future<File> _file(int appId, String name) async =>
      File('${(await _app(appId)).path}${Platform.pathSeparator}$name');

  Future<void> _atomicBytes(File target, List<int> bytes) async {
    await target.parent.create(recursive: true);
    final temporary = File(
      '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  @override
  Future<void> save(int appId, Uint8List source) async =>
      _atomicBytes(await _file(appId, 'app-side.js'), source);

  @override
  Future<void> saveSetting(
    int appId,
    Uint8List source, {
    Map<String, Uint8List> assets = const {},
    String? appName,
  }) async {
    await _atomicBytes(await _file(appId, 'setting.js'), source);
    final assetsRoot = Directory(
      '${(await _app(appId)).path}${Platform.pathSeparator}settings-assets',
    );
    if (await assetsRoot.exists()) await assetsRoot.delete(recursive: true);
    for (final entry in assets.entries) {
      final normalized = entry.key.replaceAll('\\', '/');
      if (normalized.startsWith('/') ||
          RegExp(r'^[a-zA-Z]:').hasMatch(normalized) ||
          normalized.split('/').contains('..')) {
        continue;
      }
      final target = File(
        '${assetsRoot.path}${Platform.pathSeparator}'
        '${normalized.replaceAll('/', Platform.pathSeparator)}',
      );
      await _atomicBytes(target, entry.value);
    }
    if (appName != null && appName.trim().isNotEmpty) {
      await _atomicBytes(
        await _file(appId, 'metadata.json'),
        utf8.encode(jsonEncode({'name': appName.trim()})),
      );
    }
  }

  Future<String?> _read(int appId, String name) async {
    final target = await _file(appId, name);
    if (!await target.exists()) return null;
    return target.readAsString(encoding: utf8);
  }

  @override
  Future<String?> read(int appId) => _read(appId, 'app-side.js');

  @override
  Future<String?> readSetting(int appId) => _read(appId, 'setting.js');

  @override
  Future<Map<String, Uint8List>> readSettingAssets(int appId) async {
    final root = Directory(
      '${(await _app(appId)).path}${Platform.pathSeparator}settings-assets',
    );
    if (!await root.exists()) return const {};
    final result = <String, Uint8List>{};
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = entity.path.substring(root.path.length + 1).replaceAll(
        Platform.pathSeparator,
        '/',
      );
      result[relative] = await entity.readAsBytes();
    }
    return result;
  }

  @override
  Future<String?> readAppName(int appId) async {
    final source = await _read(appId, 'metadata.json');
    if (source == null) return null;
    final decoded = jsonDecode(source);
    return decoded is Map ? decoded['name']?.toString() : null;
  }

  @override
  Future<Map<String, String>> readSettings(int appId) async {
    final source = await _read(appId, 'settings.json');
    if (source == null) return {};
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('Invalid settings.json');
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  @override
  Future<void> writeSettings(int appId, Map<String, String> values) async =>
      _atomicBytes(
        await _file(appId, 'settings.json'),
        utf8.encode(jsonEncode(values)),
      );

  @override
  Future<bool> exists(int appId) async =>
      (await _file(appId, 'app-side.js')).exists();

  @override
  Future<bool> settingExists(int appId) async =>
      (await _file(appId, 'setting.js')).exists();

  @override
  Future<List<int>> listAppIds() async {
    final root = await _root();
    if (!await root.exists()) return const [];
    final ids = <int>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = entity.uri.pathSegments
          .where((part) => part.isNotEmpty)
          .last;
      if (!RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(name)) continue;
      final id = int.parse(name, radix: 16);
      final appSide = File(
        '${entity.path}${Platform.pathSeparator}app-side.js',
      );
      final setting = File('${entity.path}${Platform.pathSeparator}setting.js');
      if (await appSide.exists() || await setting.exists()) ids.add(id);
    }
    ids.sort();
    return ids;
  }
}
