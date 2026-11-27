import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/core/ble_requirement.dart';
import 'package:oronbox/src/device/core/bluetooth_platform.dart';
import 'package:oronbox/src/device/core/transport.dart';

/// Zepp OS' virtual-GATT protocol carried over Bluetooth Classic RFCOMM.
///
/// This adapter only unwraps BTBR frames and maps virtual characteristic UUIDs.
/// Endpoint framing, authentication and file-transfer semantics remain owned by
/// their existing Zepp OS components.
class ZeppOsBtbrTransport
    implements CharacteristicTransport, TrafficReportingTransport {
  ZeppOsBtbrTransport(this._connection, {int Function()? nonceGenerator})
    : _nonceGenerator =
          nonceGenerator ?? (() => Random.secure().nextInt(0x100000000)),
      _log = getLogger('ZeppOsBtbrTransport');

  static const chunkedWriteCharacteristic =
      '00000016-0000-3512-2118-0009af100700';
  static const chunkedReadCharacteristic =
      '00000017-0000-3512-2118-0009af100700';

  static const _preamble = 0x55;
  static const _trailer = 0xaa;
  static const _channelsGet = 0x01;
  static const _channelsResponse = 0x02;
  static const _sessionStart = 0x03;
  static const _sessionStartAck = 0x04;
  static const _sessionEnd = 0x05;
  static const _sessionEndAck = 0x06;
  static const _channelData = 0x07;
  static const _channelAck = 0x08;
  static const _ping = 0x09;
  static const _pong = 0x0a;
  static const _minimumFrameLength = 8;
  static const _maximumPayloadLength = 0xffff;

  final BluetoothConnection _connection;
  final int Function() _nonceGenerator;
  final Logger _log;
  final _incomingController = StreamController<Uint8List>.broadcast();
  final _trafficMeter = LinkTrafficMeter();
  final _characteristicControllers = <String, StreamController<Uint8List>>{};
  final _channelToCharacteristic = <int, String>{};
  final _characteristicToChannel = <String, int>{};

  Completer<void>? _ready;
  Uint8List _receiveBuffer = Uint8List(0);
  int _sequenceTx = 0;
  int? _sessionNonce;
  int? _sessionNumber;
  int? _sessionMtu;
  bool _disposed = false;

  @override
  String get deviceId => _connection.deviceId;

  @override
  String get deviceName => _connection.deviceName;

  @override
  Stream<Uint8List> get incomingData => _incomingController.stream;

  @override
  Stream<LinkTraffic> get traffic => _trafficMeter.stream;

  @override
  Stream<bool> get connectionState => _connection.connectionState;

  @override
  int? get maxWriteLength => _sessionMtu;

  bool get isReady => _sessionNumber != null;

  Future<void> start() async {
    if (_disposed) throw StateError('BTBR transport is disposed');
    if (_ready != null) return _ready!.future;
    final ready = Completer<void>();
    _ready = ready;
    await _connection.subscribe(onData: _onRawData);
    try {
      await _sendFrame(_channelsGet, Uint8List(0));
      await ready.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException(
          'Zepp OS BTBR channel/session negotiation timed out',
          const Duration(seconds: 8),
        ),
      );
    } catch (error, stackTrace) {
      if (!ready.isCompleted) ready.completeError(error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> send(Uint8List data) {
    return _sendCharacteristic(chunkedWriteCharacteristic, data);
  }

  @override
  Future<void> sendToCharacteristic(
    Uint8List data,
    BleRequiredCharacteristic characteristic, {
    bool? withResponse,
  }) {
    // Gadgetbridge always sets the BTBR channel-level requestAck flag to
    // false. Zepp endpoint and file-transfer protocols provide their own ACKs.
    return _sendCharacteristic(characteristic.characteristicUuid, data);
  }

  @override
  Future<StreamSubscription<Uint8List>?> subscribeToCharacteristic(
    BleRequiredCharacteristic characteristic,
    void Function(Uint8List data) onData,
  ) async {
    final key = _normalizeUuid(characteristic.characteristicUuid);
    if (!_characteristicToChannel.containsKey(key)) {
      throw StateError(
        'BTBR characteristic ${characteristic.characteristicUuid} '
        'was not advertised by the watch',
      );
    }
    final controller = _characteristicControllers.putIfAbsent(
      key,
      () => StreamController<Uint8List>.broadcast(),
    );
    return controller.stream.listen(onData);
  }

  Future<void> _sendCharacteristic(String uuid, Uint8List data) async {
    final ready = _ready;
    if (ready == null) {
      throw StateError('Zepp OS BTBR transport has not been started');
    }
    await ready.future;
    final session = _sessionNumber;
    final channel = _characteristicToChannel[_normalizeUuid(uuid)];
    if (session == null || channel == null) {
      throw StateError('BTBR characteristic $uuid is unavailable');
    }
    final payload = Uint8List(data.length + 4);
    payload[0] = session;
    _writeUint16Le(payload, 1, channel);
    payload[3] = 0; // channel-level ACK is not requested
    payload.setRange(4, payload.length, data);
    await _sendFrame(_channelData, payload);
  }

  Future<void> _sendFrame(int command, Uint8List payload) async {
    if (_disposed) throw StateError('BTBR transport is disposed');
    if (payload.length > _maximumPayloadLength) {
      throw StateError('BTBR payload is too large: ${payload.length}');
    }
    final sequence = _sequenceTx;
    _sequenceTx = (_sequenceTx + 1) & 0xff;
    final frame = Uint8List(payload.length + 8);
    frame[0] = _preamble;
    frame[1] = command;
    frame[2] = sequence;
    _writeUint16Le(frame, 3, payload.length);
    frame.setRange(5, 5 + payload.length, payload);
    final crc = _crc16(Uint8List.sublistView(frame, 1, 5 + payload.length));
    _writeUint16Le(frame, 5 + payload.length, crc);
    frame[7 + payload.length] = _trailer;
    await _connection.send(frame);
    _trafficMeter.addUpload(frame.length);
  }

  void _onRawData(Uint8List data) {
    if (_disposed || data.isEmpty) return;
    _trafficMeter.addDownload(data.length);
    final combined = Uint8List(_receiveBuffer.length + data.length)
      ..setRange(0, _receiveBuffer.length, _receiveBuffer)
      ..setRange(
        _receiveBuffer.length,
        _receiveBuffer.length + data.length,
        data,
      );
    _receiveBuffer = combined;
    _drainFrames();
  }

  void _drainFrames() {
    var offset = 0;
    while (_receiveBuffer.length - offset >= _minimumFrameLength) {
      if (_receiveBuffer[offset] != _preamble) {
        offset += 1;
        continue;
      }
      final payloadLength = _readUint16Le(_receiveBuffer, offset + 3);
      final frameLength = payloadLength + 8;
      if (_receiveBuffer.length - offset < frameLength) break;
      final trailerOffset = offset + frameLength - 1;
      if (_receiveBuffer[trailerOffset] != _trailer) {
        _log.warning('Invalid BTBR trailer; resynchronizing');
        offset += 1;
        continue;
      }
      final expectedCrc = _readUint16Le(
        _receiveBuffer,
        offset + 5 + payloadLength,
      );
      final actualCrc = _crc16(
        Uint8List.sublistView(
          _receiveBuffer,
          offset + 1,
          offset + 5 + payloadLength,
        ),
      );
      if (expectedCrc != actualCrc) {
        _log.warning(
          'Invalid BTBR CRC: expected=${expectedCrc.toRadixString(16)}, '
          'actual=${actualCrc.toRadixString(16)}',
        );
        offset += frameLength;
        continue;
      }
      final command = _receiveBuffer[offset + 1];
      final sequence = _receiveBuffer[offset + 2];
      final payload = Uint8List.fromList(
        Uint8List.sublistView(
          _receiveBuffer,
          offset + 5,
          offset + 5 + payloadLength,
        ),
      );
      try {
        _handleFrame(command, sequence, payload);
      } catch (error, stackTrace) {
        _log.warning('Failed to handle BTBR frame', error, stackTrace);
        if (!(_ready?.isCompleted ?? true)) {
          _ready!.completeError(error, stackTrace);
        } else {
          _incomingController.addError(error, stackTrace);
        }
      }
      offset += frameLength;
    }
    if (offset == 0) return;
    _receiveBuffer = offset >= _receiveBuffer.length
        ? Uint8List(0)
        : Uint8List.fromList(Uint8List.sublistView(_receiveBuffer, offset));
  }

  void _handleFrame(int command, int sequence, Uint8List payload) {
    switch (command) {
      case _channelsResponse:
        _handleChannelsResponse(payload);
        return;
      case _sessionStartAck:
        _handleSessionStartAck(payload);
        return;
      case _sessionEnd:
        _handleSessionEnd(payload);
        return;
      case _sessionEndAck:
      case _channelAck:
      case _pong:
        return;
      case _channelData:
        _handleChannelData(sequence, payload);
        return;
      case _ping:
        _handlePing(payload);
        return;
      default:
        _log.warning(
          'Ignoring unknown BTBR command 0x${command.toRadixString(16)}',
        );
    }
  }

  void _handleChannelsResponse(Uint8List payload) {
    if (payload.length < 3) {
      throw const FormatException('BTBR channel response is too short');
    }
    final version = payload[0];
    if (version > 1) {
      throw UnsupportedError('Unsupported Zepp OS BTBR version $version');
    }
    final count = _readUint16Le(payload, 1);
    var offset = 3;
    _channelToCharacteristic.clear();
    _characteristicToChannel.clear();
    for (var index = 0; index < count; index += 1) {
      final end = payload.indexOf(0, offset);
      if (end < 0 || end + 2 >= payload.length) {
        throw const FormatException('Malformed BTBR characteristic table');
      }
      final uuid = _normalizeUuid(String.fromCharCodes(payload, offset, end));
      offset = end + 1;
      final channel = _readUint16Le(payload, offset);
      offset += 2;
      _channelToCharacteristic[channel] = uuid;
      _characteristicToChannel[uuid] = channel;
    }
    if (!_characteristicToChannel.containsKey(chunkedWriteCharacteristic) ||
        !_characteristicToChannel.containsKey(chunkedReadCharacteristic)) {
      throw StateError(
        'Watch BTBR channel table does not expose Zepp OS chunked transport',
      );
    }
    final nonce = _nonceGenerator() & 0xffffffff;
    _sessionNonce = nonce;
    final request = Uint8List(4);
    _writeUint32Le(request, 0, nonce);
    unawaited(
      _sendFrame(_sessionStart, request).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        if (!(_ready?.isCompleted ?? true)) {
          _ready!.completeError(error, stackTrace);
        }
      }),
    );
  }

  void _handleSessionStartAck(Uint8List payload) {
    if (payload.length < 8) {
      throw const FormatException('BTBR session response is too short');
    }
    final nonce = _readUint32Le(payload, 0);
    if (nonce != _sessionNonce) {
      throw StateError('BTBR session nonce mismatch');
    }
    final status = payload[4];
    if (status != 1) {
      throw StateError('BTBR session was rejected with status $status');
    }
    _sessionNumber = payload[5];
    _sessionMtu = _readUint16Le(payload, 6);
    _log.info(
      'BTBR session ready: session=$_sessionNumber, mtu=$_sessionMtu, '
      'channels=${_channelToCharacteristic.length}',
    );
    final ready = _ready;
    if (ready != null && !ready.isCompleted) ready.complete();
  }

  void _handleChannelData(int sequence, Uint8List payload) {
    if (payload.length < 4) {
      throw const FormatException('BTBR channel payload is too short');
    }
    final session = payload[0];
    if (session != _sessionNumber) {
      throw StateError('BTBR data belongs to unknown session $session');
    }
    final channel = _readUint16Le(payload, 1);
    final mustAck = payload[3] != 0;
    final uuid = _channelToCharacteristic[channel];
    if (uuid == null) {
      throw StateError('Unknown BTBR channel $channel');
    }
    final data = Uint8List.fromList(Uint8List.sublistView(payload, 4));
    _characteristicControllers[uuid]?.add(data);
    if (uuid == chunkedReadCharacteristic) {
      _incomingController.add(data);
    }
    if (mustAck) {
      final ack = Uint8List.fromList([session, sequence, 0x01, 0x00]);
      unawaited(
        _sendFrame(_channelAck, ack).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          _incomingController.addError(error, stackTrace);
        }),
      );
    }
  }

  void _handlePing(Uint8List payload) {
    if (payload.isEmpty || payload[0] != _sessionNumber) return;
    unawaited(
      _sendFrame(
        _pong,
        Uint8List.fromList([payload[0], 0x01, 0x00, 0x00]),
      ).catchError((Object error, StackTrace stackTrace) {
        _incomingController.addError(error, stackTrace);
      }),
    );
  }

  void _handleSessionEnd(Uint8List payload) {
    if (payload.isEmpty || payload[0] != _sessionNumber) return;
    _sessionNumber = null;
    final error = StateError('Zepp OS BTBR session ended');
    _incomingController.addError(error);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final controller in _characteristicControllers.values) {
      await controller.close();
    }
    _characteristicControllers.clear();
    if (!_incomingController.isClosed) await _incomingController.close();
    await _trafficMeter.dispose();
    await _connection.dispose();
  }

  static String _normalizeUuid(String value) => value.toLowerCase();

  static int _readUint16Le(Uint8List bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int _readUint32Le(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);

  static void _writeUint16Le(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
  }

  static void _writeUint32Le(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
    bytes[offset + 2] = (value >> 16) & 0xff;
    bytes[offset + 3] = (value >> 24) & 0xff;
  }

  static int _crc16(Uint8List bytes) {
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
}
