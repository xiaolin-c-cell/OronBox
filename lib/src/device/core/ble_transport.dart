import 'dart:async';
import 'dart:typed_data';

import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/services/ble_gatt_driver.dart';
import 'package:oronbox/src/device/core/bluetooth_platform.dart';
import 'package:oronbox/src/device/core/transport.dart';

class BleTransport
    implements CharacteristicTransport, TrafficReportingTransport {
  BleTransport.xiaomi(BleConnection connection)
    : _bleConnection = connection,
      _bluetoothConnection = null,
      _serviceUuid = _xiaomiServiceUuid,
      _recvCharUuid = _xiaomiRecvCharUuid,
      _sentCharUuid = _xiaomiSentCharUuid,
      _defaultWithResponse = false;

  BleTransport.zepp(BleConnection connection)
    : _bleConnection = connection,
      _bluetoothConnection = null,
      _serviceUuid = _zeppServiceUuid,
      _recvCharUuid = _zeppRecvCharUuid,
      _sentCharUuid = _zeppSentCharUuid,
      _defaultWithResponse = true;

  BleTransport.xiaomiBluetooth(BluetoothConnection connection)
    : _bleConnection = null,
      _bluetoothConnection = connection,
      _serviceUuid = _xiaomiServiceUuid,
      _recvCharUuid = _xiaomiRecvCharUuid,
      _sentCharUuid = _xiaomiSentCharUuid,
      _defaultWithResponse = false;

  BleTransport.zeppBluetooth(BluetoothConnection connection)
    : _bleConnection = null,
      _bluetoothConnection = connection,
      _serviceUuid = _zeppServiceUuid,
      _recvCharUuid = _zeppRecvCharUuid,
      _sentCharUuid = _zeppSentCharUuid,
      _defaultWithResponse = true;

  static final _log = getLogger('BleTransport');
  final BleConnection? _bleConnection;
  final BluetoothConnection? _bluetoothConnection;
  final String _serviceUuid;
  final String _recvCharUuid;
  final String _sentCharUuid;
  final bool _defaultWithResponse;

  final _incomingController = StreamController<Uint8List>.broadcast();
  final _trafficMeter = LinkTrafficMeter();
  StreamSubscription<Uint8List>? _valueSubscription;
  bool _protocolNotificationsActive = false;
  Completer<void>? _exclusiveWriteGate;
  Set<String> _exclusiveCharacteristics = const {};
  final _characteristicSubscriptions = <StreamSubscription<Uint8List>>[];
  StreamSubscription<bool>? _connectionSubscription;

  static const String _xiaomiServiceUuid =
      '0000fe95-0000-1000-8000-00805f9b34fb';
  static const String _xiaomiRecvCharUuid =
      '0000005e-0000-1000-8000-00805f9b34fb';
  static const String _xiaomiSentCharUuid =
      '0000005f-0000-1000-8000-00805f9b34fb';

  static const String _zeppServiceUuid = '00001530-0000-3512-2118-0009af100700';
  static const String _zeppRecvCharUuid =
      '00000017-0000-3512-2118-0009af100700';
  static const String _zeppSentCharUuid =
      '00000016-0000-3512-2118-0009af100700';

  @override
  String get deviceId =>
      _bleConnection?.deviceId ?? _bluetoothConnection!.deviceId;

  @override
  String get deviceName =>
      _bleConnection?.deviceName ?? _bluetoothConnection!.deviceName;

  @override
  Stream<Uint8List> get incomingData => _incomingController.stream;

  @override
  Stream<LinkTraffic> get traffic => _trafficMeter.stream;

  void _onProtocolData(Uint8List data) {
    _trafficMeter.addDownload(data.length);
    _incomingController.add(data);
  }

  @override
  Stream<bool> get connectionState =>
      _bleConnection?.connectionState ?? _bluetoothConnection!.connectionState;

  @override
  int? get maxWriteLength {
    final connection = _bleConnection;
    if (connection != null) {
      return (connection.mtu.clamp(23, 515) - 3).clamp(20, 512);
    }
    return _bluetoothConnection?.maxWriteLength;
  }

  Future<void> start() async {
    _log.fine('[$deviceId] starting transport on recv=$_recvCharUuid');
    final bleConnection = _bleConnection;
    if (bleConnection != null) {
      _valueSubscription = await bleConnection.subscribe(
        _serviceUuid,
        _recvCharUuid,
        _onProtocolData,
      );
    } else {
      await _bluetoothConnection!.subscribe(
        characteristic: BleRequiredCharacteristic(
          serviceUuid: _serviceUuid,
          characteristicUuid: _recvCharUuid,
        ),
        onData: _onProtocolData,
      );
    }
    _protocolNotificationsActive = true;
    _connectionSubscription = connectionState.listen(
      (connected) {
        _log.info('[$deviceId] transport connection state: $connected');
        if (!connected && !_incomingController.isClosed) {
          _incomingController.close();
        }
      },
      onError: (Object e) =>
          _log.warning('[$deviceId] connection stream error', e),
    );
  }

  /// Temporarily stops the normal protocol notification stream while the
  /// firmware characteristics own the BLE link exclusively.
  Future<void> suspendProtocolNotifications() async {
    final connection = _bleConnection;
    if (connection != null) {
      if (_valueSubscription == null) return;
      await _valueSubscription?.cancel();
      _valueSubscription = null;
      await connection.unsubscribe(_serviceUuid, _recvCharUuid);
    } else {
      if (!_protocolNotificationsActive) return;
      await _bluetoothConnection!.unsubscribe(
        characteristic: BleRequiredCharacteristic(
          serviceUuid: _serviceUuid,
          characteristicUuid: _recvCharUuid,
        ),
      );
    }
    _protocolNotificationsActive = false;
  }

  Future<void> resumeProtocolNotifications() async {
    final connection = _bleConnection;
    if (connection != null) {
      if (_valueSubscription != null) return;
      _valueSubscription = await connection.subscribe(
        _serviceUuid,
        _recvCharUuid,
        _onProtocolData,
      );
    } else {
      if (_protocolNotificationsActive) return;
      await _bluetoothConnection!.subscribe(
        characteristic: BleRequiredCharacteristic(
          serviceUuid: _serviceUuid,
          characteristicUuid: _recvCharUuid,
        ),
        onData: _onProtocolData,
      );
    }
    _protocolNotificationsActive = true;
  }

  Future<int?> requestMtu(int desiredMtu) async {
    final connection = _bleConnection;
    if (connection == null) return null;
    return connection.requestMtu(desiredMtu);
  }

  void beginExclusiveCharacteristicWrites(Iterable<String> characteristics) {
    if (_exclusiveWriteGate != null) {
      throw StateError('An exclusive BLE operation is already active');
    }
    _exclusiveCharacteristics = characteristics
        .map((value) => value.toLowerCase())
        .toSet();
    _exclusiveWriteGate = Completer<void>();
  }

  void endExclusiveCharacteristicWrites() {
    final gate = _exclusiveWriteGate;
    _exclusiveWriteGate = null;
    _exclusiveCharacteristics = const {};
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<void> send(Uint8List data) async {
    _log.fine('[$deviceId] sending ${data.length} bytes');
    await sendToCharacteristic(
      data,
      BleRequiredCharacteristic(
        serviceUuid: _serviceUuid,
        characteristicUuid: _sentCharUuid,
      ),
      withResponse: _defaultWithResponse,
    );
  }

  @override
  Future<void> sendToCharacteristic(
    Uint8List data,
    BleRequiredCharacteristic characteristic, {
    bool? withResponse,
  }) async {
    final gate = _exclusiveWriteGate;
    if (gate != null &&
        !_exclusiveCharacteristics.contains(
          characteristic.characteristicUuid.toLowerCase(),
        )) {
      await gate.future;
    }
    final effectiveWithResponse = withResponse ?? _defaultWithResponse;
    _log.fine(
      '[$deviceId] sending ${data.length} bytes to '
      '${characteristic.characteristicUuid}',
    );
    final bleConnection = _bleConnection;
    if (bleConnection != null) {
      await bleConnection.write(
        characteristic.serviceUuid,
        characteristic.characteristicUuid,
        data,
        withResponse: effectiveWithResponse,
      );
    } else {
      await _bluetoothConnection!.send(
        data,
        characteristic: characteristic,
        withResponse: effectiveWithResponse,
      );
    }
    _trafficMeter.addUpload(data.length);
  }

  @override
  Future<StreamSubscription<Uint8List>?> subscribeToCharacteristic(
    BleRequiredCharacteristic characteristic,
    void Function(Uint8List data) onData,
  ) async {
    final bleConnection = _bleConnection;
    if (bleConnection != null) {
      final subscription = await bleConnection.subscribe(
        characteristic.serviceUuid,
        characteristic.characteristicUuid,
        (data) {
          _trafficMeter.addDownload(data.length);
          onData(data);
        },
      );
      _characteristicSubscriptions.add(subscription);
      return subscription;
    }
    await _bluetoothConnection!.subscribe(
      characteristic: characteristic,
      onData: (data) {
        _trafficMeter.addDownload(data.length);
        onData(data);
      },
    );
    return null;
  }

  @override
  Future<void> dispose() async {
    _log.fine('[$deviceId] disposing transport');
    await _valueSubscription?.cancel();
    _valueSubscription = null;
    for (final subscription in _characteristicSubscriptions) {
      await subscription.cancel();
    }
    _characteristicSubscriptions.clear();
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
    await _trafficMeter.dispose();
    await (_bleConnection?.dispose() ?? _bluetoothConnection!.dispose());
  }
}
