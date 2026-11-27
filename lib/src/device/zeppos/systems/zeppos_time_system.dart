import 'dart:async';
import 'dart:typed_data';

import 'package:oronbox/src/device/core/ble_requirement.dart';
import 'package:oronbox/src/device/core/system.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_component.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_services_system.dart';

class ZeppOsTimeSystem extends System {
  static const endpoint = 0x0047;
  static const _setTime = 0x05;
  static const _setTimeAck = 0x06;
  static const _currentTimeCharacteristic = BleRequiredCharacteristic(
    serviceUuid: '00001805-0000-1000-8000-00805f9b34fb',
    characteristicUuid: '00002a2b-0000-1000-8000-00805f9b34fb',
    label: 'current time',
  );

  Completer<void>? _pending;

  Future<void> syncTime() async {
    final pending = _pending;
    if (pending != null) return pending.future;

    final servicesSystem = entity.system<ZeppOsServicesSystem>();
    if (servicesSystem == null) {
      throw UnsupportedError('ZeppOS service discovery is not available');
    }
    final services = await servicesSystem.fetchSupportedServices();
    if (!services.containsKey(endpoint)) {
      await _syncLegacyBleTime();
      return;
    }

    final completer = Completer<void>();
    _pending = completer;
    try {
      await entity.getRequired<ZeppOsDeviceComponent>().sendToEndpoint(
        endpoint,
        Uint8List.fromList([_setTime, ..._encodeCurrentTime(DateTime.now())]),
        encrypted: services[endpoint] ?? false,
      );
      await completer.future.timeout(const Duration(seconds: 8));
    } finally {
      if (identical(_pending, completer)) _pending = null;
    }
  }

  Future<void> _syncLegacyBleTime() async {
    final transport = entity.transport;
    if (transport is! CharacteristicTransport) {
      throw UnsupportedError('ZeppOS time synchronization is not available');
    }
    try {
      await transport.sendToCharacteristic(
        _encodeCurrentTime(DateTime.now()),
        _currentTimeCharacteristic,
        withResponse: true,
      );
    } on StateError catch (error) {
      throw UnsupportedError(
        'ZeppOS time synchronization is not available: $error',
      );
    }
  }

  void handlePayload(Uint8List payload) {
    if (payload.length < 2 || payload[0] != _setTimeAck) return;
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    if (payload[1] == 1) {
      pending.complete();
    } else {
      pending.completeError(
        StateError('ZeppOS time synchronization failed: ${payload[1]}'),
      );
    }
  }

  Uint8List _encodeCurrentTime(DateTime now) {
    final result = Uint8List(11);
    final data = ByteData.sublistView(result);
    data.setUint16(0, now.year, Endian.little);
    result[2] = now.month;
    result[3] = now.day;
    result[4] = now.hour;
    result[5] = now.minute;
    result[6] = now.second;
    result[7] = now.weekday % 7;
    result[8] = (now.millisecond * 256 ~/ 1000).clamp(0, 255).toInt();
    result[9] = 0;
    data.setInt8(10, now.timeZoneOffset.inMinutes ~/ 15);
    return result;
  }

  @override
  void onData(Uint8List data) {}
}
