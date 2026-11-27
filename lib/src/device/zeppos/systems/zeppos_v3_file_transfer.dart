import 'dart:async';
import 'dart:typed_data';

import 'package:oronbox/src/device/core/ble_requirement.dart';
import 'package:oronbox/src/device/core/transport.dart';

class ZeppOsV3FileTransfer {
  ZeppOsV3FileTransfer({
    required this.transport,
    required this.characteristic,
    required this.transferLabel,
  });

  final CharacteristicTransport transport;
  final BleRequiredCharacteristic characteristic;
  final String transferLabel;
  Completer<int>? _chunkAck;

  Future<void> send({
    required Uint8List bytes,
    required int initialOffset,
    required int chunkSize,
    void Function(double progress)? onProgress,
  }) async {
    if (_chunkAck != null) {
      throw StateError('$transferLabel transfer is already active');
    }
    if (chunkSize <= 0) throw StateError('Invalid V3 chunk size: $chunkSize');
    if (initialOffset < 0 || initialOffset > bytes.length) {
      throw StateError('Invalid $transferLabel progress: $initialOffset');
    }

    var offset = initialOffset;
    var index = offset ~/ chunkSize;
    onProgress?.call(bytes.isEmpty ? 1 : offset / bytes.length);
    while (offset < bytes.length) {
      final length = (bytes.length - offset).clamp(0, chunkSize);
      final last = offset + length == bytes.length;
      final packet = Uint8List(5 + length)
        ..[0] = 0x12
        ..[1] = (offset == 0 ? 1 : 0) | (last ? 2 : 0)
        ..[2] = index & 0xff;
      ByteData.sublistView(packet).setUint16(3, length, Endian.little);
      packet.setRange(5, packet.length, bytes, offset);

      final ack = Completer<int>();
      _chunkAck = ack;
      try {
        await _write(packet);
        final acknowledged = await ack.future.timeout(
          const Duration(seconds: 20),
        );
        if (acknowledged != (index & 0xff)) {
          throw StateError(
            '$transferLabel chunk acknowledgement mismatch: '
            '$acknowledged/${index & 0xff}',
          );
        }
      } finally {
        if (identical(_chunkAck, ack)) _chunkAck = null;
      }
      offset += length;
      index++;
      onProgress?.call(offset / bytes.length);
    }
  }

  void handleAck(Uint8List payload) {
    if (payload.length < 3 || payload[0] != 0x13) return;
    final pending = _chunkAck;
    if (pending == null || pending.isCompleted) return;
    if (payload[1] == 0) {
      pending.complete(payload[2]);
    } else {
      pending.completeError(
        StateError('$transferLabel chunk write failed: ${payload[1]}'),
      );
    }
  }

  Future<void> _write(Uint8List packet) async {
    final writeLength = transport.maxWriteLength ?? packet.length;
    if (writeLength <= 0) {
      throw StateError('Invalid V3 write length: $writeLength');
    }
    for (var offset = 0; offset < packet.length; offset += writeLength) {
      final end = (offset + writeLength).clamp(0, packet.length);
      await transport.sendToCharacteristic(
        Uint8List.sublistView(packet, offset, end),
        characteristic,
        withResponse: false,
      );
    }
  }
}

int zeppOsFileCrc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
