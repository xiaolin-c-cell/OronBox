import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/features/devices/controllers/interconnect_event_codec.dart';

void main() {
  test('interconnect messages survive the host event boundary', () {
    final message = InterconnectMessage(
      deviceId: 'watch-1',
      pkgName: 'com.bandbbs.ebook',
      payload: Uint8List.fromList([0, 1, 127, 255]),
    );

    final event = CommandEvent(
      deviceInterconnectEvent,
      data: encodeInterconnectEvent(message),
    );
    final decoded = decodeInterconnectEvent(event);

    expect(decoded?.deviceId, message.deviceId);
    expect(decoded?.pkgName, message.pkgName);
    expect(decoded?.payload, orderedEquals(message.payload));
  });

  test('malformed or unrelated host events are ignored', () {
    expect(decodeInterconnectEvent(const CommandEvent('device.state')), isNull);
    expect(
      decodeInterconnectEvent(
        const CommandEvent(
          deviceInterconnectEvent,
          data: {'deviceId': 'watch-1', 'packageName': 'com.example'},
        ),
      ),
      isNull,
    );
  });
}
