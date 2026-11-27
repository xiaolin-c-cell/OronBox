import 'dart:typed_data';

import 'zeppos_app_side_storage.dart';

ZeppOsAppSideStorage createZeppOsAppSideStorage() =>
    _UnsupportedZeppOsAppSideStorage();

class _UnsupportedZeppOsAppSideStorage implements ZeppOsAppSideStorage {
  Never _unsupported() =>
      throw UnsupportedError('Zepp OS local app storage is unavailable');

  @override
  Future<bool> exists(int appId) async => false;

  @override
  Future<bool> settingExists(int appId) async => false;

  @override
  Future<List<int>> listAppIds() async => const [];

  @override
  Future<String?> read(int appId) async => null;

  @override
  Future<String?> readSetting(int appId) async => null;

  @override
  Future<Map<String, Uint8List>> readSettingAssets(int appId) async => const {};

  @override
  Future<String?> readAppName(int appId) async => null;

  @override
  Future<Map<String, String>> readSettings(int appId) async => const {};

  @override
  Future<void> writeSettings(int appId, Map<String, String> values) async =>
      _unsupported();

  @override
  Future<void> save(int appId, Uint8List source) async => _unsupported();

  @override
  Future<void> saveSetting(
    int appId,
    Uint8List source, {
    Map<String, Uint8List> assets = const {},
    String? appName,
  }) async => _unsupported();
}
