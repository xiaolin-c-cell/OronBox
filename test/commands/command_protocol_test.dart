import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/commands/command_protocol.dart';

void main() {
  test('command survives JSON transport', () {
    const command = OronBoxCommand(
      method: 'install.local',
      params: {'type': 'quickapp', 'path': '/tmp/app.rpk'},
    );
    final decoded = jsonDecode(jsonEncode(command.toJson()));
    final restored = OronBoxCommand.fromJson(
      (decoded as Map).cast<String, Object?>(),
    );
    expect(restored.method, command.method);
    expect(restored.params, command.params);
  });

  test('error result survives JSON transport', () {
    const result = CommandResult.failure(
      CommandError('no_device', 'No paired device'),
    );
    final restored = CommandResult.fromJson(result.toJson());
    expect(restored.ok, isFalse);
    expect(restored.error?.code, 'no_device');
  });
}
