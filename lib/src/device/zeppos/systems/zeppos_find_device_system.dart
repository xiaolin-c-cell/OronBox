import 'dart:typed_data';

import 'package:oronbox/src/device/core/system.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_component.dart';

class ZeppOsFindDeviceSystem extends System {
  static const endpoint = 0x001a;
  static const _findBandStart = 0x03;
  static const _findBandStopFromPhone = 0x06;

  Future<void> setFinding(bool finding) {
    return entity.getRequired<ZeppOsDeviceComponent>().sendToEndpoint(
      endpoint,
      Uint8List.fromList([
        finding ? _findBandStart : _findBandStopFromPhone,
      ]),
      encrypted: true,
    );
  }

  @override
  void onData(Uint8List data) {}
}
