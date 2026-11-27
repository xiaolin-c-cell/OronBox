import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/logging/file_log_sink_io.dart';

void main() {
  test('serializes rapid writes and flushes every line', () async {
    final directory = await Directory.systemTemp.createTemp(
      'oronbox_log_writer_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/test.log');
    final writer = SerialFileLogWriter(file.openWrite());

    for (var index = 0; index < 200; index += 1) {
      writer.writeLine('line-$index');
    }
    await writer.close();

    expect(await file.readAsLines(), [
      for (var index = 0; index < 200; index += 1) 'line-$index',
    ]);
  });
}
