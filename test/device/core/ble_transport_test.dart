import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/ble_requirement.dart';
import 'package:oronbox/src/device/core/ble_transport.dart';
import 'package:oronbox/src/device/core/bluetooth_platform.dart';
import 'package:oronbox/src/device/core/connect_type.dart';

void main() {
  test('explicit write mode overrides the Zepp transport default', () async {
    final connection = _FakeBluetoothConnection();
    final transport = BleTransport.zeppBluetooth(connection);
    const characteristic = BleRequiredCharacteristic(
      serviceUuid: 'service',
      characteristicUuid: 'characteristic',
    );

    await transport.sendToCharacteristic(
      Uint8List.fromList(const [0x13, 0, 0, 1, 0, 0, 0]),
      characteristic,
      withResponse: false,
    );
    await transport.sendToCharacteristic(
      Uint8List.fromList(const [0x01]),
      characteristic,
    );

    expect(connection.writeModes, [false, true]);
  });
}

class _FakeBluetoothConnection implements BluetoothConnection {
  final writeModes = <bool>[];

  @override
  Stream<bool> get connectionState => const Stream.empty();

  @override
  ConnectType get connectType => ConnectType.ble;

  @override
  String get deviceId => 'test-device';

  @override
  String get deviceName => 'test-zepp';

  @override
  Stream<Uint8List> get incomingData => const Stream.empty();

  @override
  int get maxWriteLength => 244;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> send(
    Uint8List data, {
    BleRequiredCharacteristic? characteristic,
    bool withResponse = false,
  }) async {
    writeModes.add(withResponse);
  }

  @override
  Future<void> subscribe({
    BleRequiredCharacteristic? characteristic,
    void Function(Uint8List data)? onData,
  }) async {}

  @override
  Future<void> unsubscribe({BleRequiredCharacteristic? characteristic}) async {}

  @override
  bool supportsCharacteristic(BleRequiredCharacteristic characteristic) => true;
}
