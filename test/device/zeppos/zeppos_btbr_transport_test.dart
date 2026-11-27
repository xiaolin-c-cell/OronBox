import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/ble_requirement.dart';
import 'package:oronbox/src/device/core/bluetooth_platform.dart';
import 'package:oronbox/src/device/core/connect_type.dart';
import 'package:oronbox/src/device/zeppos/zeppos_btbr_transport.dart';

void main() {
  test('negotiates BTBR channels and routes virtual characteristics', () async {
    final connection = _FakeBluetoothConnection();
    final transport = ZeppOsBtbrTransport(
      connection,
      nonceGenerator: () => 0x78563412,
    );

    final starting = transport.start();
    await _flush();
    expect(_decodeFrame(connection.writes.single).command, 0x01);

    final channels = _channelTable({
      ZeppOsBtbrTransport.chunkedWriteCharacteristic: 0x10,
      ZeppOsBtbrTransport.chunkedReadCharacteristic: 0x11,
      '00000023-0000-3512-2118-0009af100700': 0x23,
      '00000024-0000-3512-2118-0009af100700': 0x24,
    });
    final channelsFrame = _encodeFrame(0x02, 4, channels);
    connection.emit(Uint8List.sublistView(channelsFrame, 0, 7));
    connection.emit(Uint8List.sublistView(channelsFrame, 7));
    await _flush();

    final sessionRequest = _decodeFrame(connection.writes.last);
    expect(sessionRequest.command, 0x03);
    expect(
      sessionRequest.payload,
      Uint8List.fromList([0x12, 0x34, 0x56, 0x78]),
    );

    connection.emit(
      _encodeFrame(
        0x04,
        5,
        Uint8List.fromList([0x12, 0x34, 0x56, 0x78, 0x01, 0x07, 0x00, 0x20]),
      ),
    );
    await starting;
    expect(transport.isReady, isTrue);
    expect(transport.maxWriteLength, 8192);

    final receivedV3 = Completer<Uint8List>();
    final subscription = await transport.subscribeToCharacteristic(
      const BleRequiredCharacteristic(
        serviceUuid: 'ignored-over-btbr',
        characteristicUuid: '00000024-0000-3512-2118-0009af100700',
      ),
      receivedV3.complete,
    );
    connection.emit(
      _encodeFrame(
        0x07,
        9,
        Uint8List.fromList([0x07, 0x24, 0x00, 0x01, 1, 2, 3]),
      ),
    );
    expect(await receivedV3.future, Uint8List.fromList([1, 2, 3]));
    await _flush();
    final channelAck = _decodeFrame(connection.writes.last);
    expect(channelAck.command, 0x08);
    expect(channelAck.payload, Uint8List.fromList([0x07, 0x09, 0x01, 0x00]));

    await transport.sendToCharacteristic(
      Uint8List.fromList([0x13, 0, 1]),
      const BleRequiredCharacteristic(
        serviceUuid: 'ignored-over-btbr',
        characteristicUuid: '00000024-0000-3512-2118-0009af100700',
      ),
      withResponse: false,
    );
    final outbound = _decodeFrame(connection.writes.last);
    expect(outbound.command, 0x07);
    expect(
      outbound.payload,
      Uint8List.fromList([0x07, 0x24, 0x00, 0x00, 0x13, 0x00, 0x01]),
    );

    await subscription?.cancel();
    await transport.dispose();
  });

  test('emits chunked endpoint data on the main incoming stream', () async {
    final connection = _FakeBluetoothConnection();
    final transport = ZeppOsBtbrTransport(connection, nonceGenerator: () => 1);
    final starting = transport.start();
    await _flush();
    connection.emit(
      _encodeFrame(
        0x02,
        1,
        _channelTable({
          ZeppOsBtbrTransport.chunkedWriteCharacteristic: 0x16,
          ZeppOsBtbrTransport.chunkedReadCharacteristic: 0x17,
        }),
      ),
    );
    await _flush();
    connection.emit(
      _encodeFrame(0x04, 2, Uint8List.fromList([1, 0, 0, 0, 1, 3, 0xf7, 0x00])),
    );
    await starting;

    final incoming = transport.incomingData.first;
    connection.emit(
      _encodeFrame(
        0x07,
        3,
        Uint8List.fromList([3, 0x17, 0, 0, 0x03, 0x03, 0, 1]),
      ),
    );
    expect(await incoming, Uint8List.fromList([0x03, 0x03, 0, 1]));
    await transport.dispose();
  });
}

class _FakeBluetoothConnection implements BluetoothConnection {
  final _incoming = StreamController<Uint8List>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  final writes = <Uint8List>[];
  StreamSubscription<Uint8List>? _subscription;

  void emit(Uint8List data) => _incoming.add(data);

  @override
  String get deviceId => 'watch';

  @override
  String get deviceName => 'Zepp OS watch';

  @override
  ConnectType get connectType => ConnectType.spp;

  @override
  Stream<Uint8List> get incomingData => _incoming.stream;

  @override
  Stream<bool> get connectionState => _connection.stream;

  @override
  int? get maxWriteLength => null;

  @override
  bool supportsCharacteristic(BleRequiredCharacteristic characteristic) =>
      false;

  @override
  Future<void> send(
    Uint8List data, {
    BleRequiredCharacteristic? characteristic,
    bool withResponse = false,
  }) async {
    writes.add(Uint8List.fromList(data));
  }

  @override
  Future<void> subscribe({
    BleRequiredCharacteristic? characteristic,
    void Function(Uint8List data)? onData,
  }) async {
    await _subscription?.cancel();
    _subscription = _incoming.stream.listen(onData);
  }

  @override
  Future<void> unsubscribe({BleRequiredCharacteristic? characteristic}) async {
    await _subscription?.cancel();
    _subscription = null;
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _incoming.close();
    await _connection.close();
  }
}

Uint8List _channelTable(Map<String, int> channels) {
  final bytes = BytesBuilder()
    ..addByte(1)
    ..add([channels.length & 0xff, (channels.length >> 8) & 0xff]);
  for (final entry in channels.entries) {
    bytes
      ..add(entry.key.codeUnits)
      ..addByte(0)
      ..add([entry.value & 0xff, (entry.value >> 8) & 0xff]);
  }
  return bytes.takeBytes();
}

Uint8List _encodeFrame(int command, int sequence, Uint8List payload) {
  final frame = Uint8List(payload.length + 8);
  frame[0] = 0x55;
  frame[1] = command;
  frame[2] = sequence;
  frame[3] = payload.length & 0xff;
  frame[4] = (payload.length >> 8) & 0xff;
  frame.setRange(5, 5 + payload.length, payload);
  final crc = _crc16(Uint8List.sublistView(frame, 1, 5 + payload.length));
  frame[5 + payload.length] = crc & 0xff;
  frame[6 + payload.length] = (crc >> 8) & 0xff;
  frame[7 + payload.length] = 0xaa;
  return frame;
}

({int command, int sequence, Uint8List payload}) _decodeFrame(Uint8List frame) {
  expect(frame.first, 0x55);
  expect(frame.last, 0xaa);
  final length = frame[3] | (frame[4] << 8);
  final expected = frame[5 + length] | (frame[6 + length] << 8);
  expect(_crc16(Uint8List.sublistView(frame, 1, 5 + length)), expected);
  return (
    command: frame[1],
    sequence: frame[2],
    payload: Uint8List.fromList(Uint8List.sublistView(frame, 5, 5 + length)),
  );
}

int _crc16(Uint8List bytes) {
  var crc = 0xffff;
  for (final byte in bytes) {
    crc = ((crc >> 8) | (crc << 8)) & 0xffff;
    crc ^= byte;
    crc ^= (crc & 0xff) >> 4;
    crc ^= (crc << 12) & 0xffff;
    crc ^= ((crc & 0xff) << 5) & 0xffff;
  }
  return crc & 0xffff;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);
