import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/ble_requirement.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_map_upload_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_services_system.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_component.dart';

void main() {
  test('accepts a Gadgetbridge-compatible Zepp OS map package', () {
    final bytes = _mapArchive('11/10/20.img');

    final package = ZeppOsMapPackage.validate(bytes, fileName: 'map.zip');

    expect(package.uncompressedSize, 512);
    expect(package.tiles, hasLength(1));
    expect((package.tiles.single.x, package.tiles.single.y), (10, 20));
  });

  test('rejects a map tile outside the supported directory layout', () {
    final bytes = _mapArchive('maps/10/20.img');

    expect(
      () => ZeppOsMapPackage.validate(bytes, fileName: 'map.zip'),
      throwsFormatException,
    );
  });

  test('rejects a map tile without the DSKIMG signature', () {
    final bytes = _mapArchive('11/10/20.img', validSignature: false);

    expect(
      () => ZeppOsMapPackage.validate(bytes, fileName: 'map.zip'),
      throwsFormatException,
    );
  });

  test('uploads a map over the Zepp OS v3 BLE characteristic', () async {
    final transport = _FakeCharacteristicTransport();
    final entity = DeviceEntity(
      id: 'test-device',
      kind: 'zeppos',
      transport: transport,
      eventBus: DeviceEventBus(),
    );
    entity.set(ZeppOsDeviceComponent(transport: transport));
    final services = ZeppOsServicesSystem();
    final maps = ZeppOsMapUploadSystem();
    entity.registerSystem(services);
    entity.registerSystem(maps);
    final bytes = _mapArchive('11/10/20.img');
    final progress = <double>[];

    final upload = maps.upload(
      bytes,
      fileName: 'map.zip',
      onProgress: progress.add,
    );
    await _flush();
    services.handlePayload(
      Uint8List.fromList(const [
        0x04,
        3,
        0,
          0x46,
          0,
          0,
          0x01,
          0,
          0,
          0x0d,
          0,
          0,
      ]),
    );
    await _flush();
    maps.handlePayload(
      ZeppOsMapUploadSystem.fileTransferEndpoint,
      Uint8List.fromList(const [0x02, 3, 0x00, 0x20]),
    );
    await _flush();
    maps.handlePayload(
      ZeppOsMapUploadSystem.mapsEndpoint,
      Uint8List.fromList(const [0x06, 1]),
    );
    final url =
        'https://gadgetbridge.freeyourgadget.nodomain/map/0.zip'
        '?type=1&zipsize=${bytes.length}';
    maps.handlePayload(
      ZeppOsMapUploadSystem.httpEndpoint,
      Uint8List.fromList([0x03, 7, ...utf8.encode(url), 0]),
    );
    await _flush();
    maps.handlePayload(
      ZeppOsMapUploadSystem.fileTransferEndpoint,
      Uint8List.fromList(const [0x04, 7, 0, 0, 0, 0, 0, 1]),
    );

    await upload;
    expect(transport.characteristicWrites, isNotEmpty);
    expect(progress.last, 1);
    await entity.dispose();
  });
}

Uint8List _mapArchive(String path, {bool validSignature = true}) {
  final tile = Uint8List(512);
  if (validSignature) {
    tile.setRange(0x10, 0x17, const [0x44, 0x53, 0x4b, 0x49, 0x4d, 0x47, 0]);
  }
  final archive = Archive()..addFile(ArchiveFile(path, tile.length, tile));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _FakeCharacteristicTransport implements CharacteristicTransport {
  final writes = <Uint8List>[];
  final characteristicWrites = <Uint8List>[];
  void Function(Uint8List)? _ackHandler;

  @override
  String get deviceId => 'test-device';
  @override
  String get deviceName => 'Test Zepp OS';
  @override
  int get maxWriteLength => 65535;
  @override
  Stream<Uint8List> get incomingData => const Stream.empty();
  @override
  Stream<bool> get connectionState => const Stream.empty();

  @override
  Future<void> send(Uint8List data) async {
    writes.add(Uint8List.fromList(data));
  }

  @override
  Future<void> sendToCharacteristic(
    Uint8List data,
    BleRequiredCharacteristic characteristic, {
    bool? withResponse,
  }) async {
    characteristicWrites.add(Uint8List.fromList(data));
    if (data.length >= 3 && data[0] == 0x12) {
      _ackHandler?.call(Uint8List.fromList([0x13, 0, data[2], 0]));
    }
  }

  @override
  Future<StreamSubscription<Uint8List>?> subscribeToCharacteristic(
    BleRequiredCharacteristic characteristic,
    void Function(Uint8List data) onData,
  ) async {
    _ackHandler = onData;
    return null;
  }

  @override
  Future<void> dispose() async {}
}
