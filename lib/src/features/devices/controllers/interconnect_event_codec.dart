import 'dart:typed_data';

import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/device/core/event_bus.dart';

const deviceInterconnectEvent = 'device.interconnect';

Map<String, Object?> encodeInterconnectEvent(InterconnectMessage message) => {
  'deviceId': message.deviceId,
  'packageName': message.pkgName,
  'payload': message.payload.toList(growable: false),
};

InterconnectMessage? decodeInterconnectEvent(CommandEvent event) {
  if (event.event != deviceInterconnectEvent) return null;
  final payload = event.data['payload'];
  final bytes = switch (payload) {
    Uint8List value => value,
    List value => Uint8List.fromList(
      value.whereType<num>().map((item) => item.toInt() & 0xff).toList(),
    ),
    _ => null,
  };
  if (bytes == null) return null;
  final packageName = event.data['packageName']?.toString() ?? '';
  final deviceId = event.data['deviceId']?.toString() ?? '';
  if (packageName.isEmpty || deviceId.isEmpty) return null;
  return InterconnectMessage(
    deviceId: deviceId,
    pkgName: packageName,
    payload: bytes,
  );
}
