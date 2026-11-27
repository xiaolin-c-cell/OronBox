import 'dart:async';
import 'dart:typed_data';

import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/system.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_component.dart';

class ZeppOsDeviceInfoSystem extends System {
  static const endpoint = 0x0043;
  static const _request = 0x01;
  static const _reply = 0x02;

  Completer<SystemInfo>? _pending;
  bool encrypted = false;
  int? productId;
  int? productVersion;
  int? deviceSource;

  Future<SystemInfo> fetchDeviceInfo() async {
    final pending = _pending;
    if (pending != null) return pending.future;
    final completer = Completer<SystemInfo>();
    _pending = completer;
    try {
      await entity.getRequired<ZeppOsDeviceComponent>().sendToEndpoint(
        endpoint,
        Uint8List.fromList(const [_request]),
        encrypted: encrypted,
      );
      return await completer.future.timeout(const Duration(seconds: 8));
    } finally {
      if (identical(_pending, completer)) _pending = null;
    }
  }

  void handlePayload(Uint8List payload) {
    if (payload.length < 10 || payload[0] != _reply || payload[1] != 1) {
      return;
    }
    final reader = _Reader(payload, 10);
    final flags = ByteData.sublistView(
      payload,
      2,
      10,
    ).getUint64(0, Endian.little);

    if (flags & 1 != 0 && reader.hasRemaining) {
      final count = reader.readByte();
      reader.skip(count);
    }
    final serialNumber = flags & 2 != 0 ? reader.readCString() : '';
    final hardwareVersion = flags & 4 != 0 ? reader.readCString() : '';
    final firmwareVersion = flags & 8 != 0 ? reader.readCString() : '';
    var pnpId = '';
    if (flags & 16 != 0 && reader.remaining >= 7) {
      final pnpBytes = reader.readBytes(7);
      pnpId = pnpBytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();
      productId = pnpBytes[3] | (pnpBytes[4] << 8);
      productVersion = pnpBytes[5] | (pnpBytes[6] << 8);
      deviceSource = _resolveDeviceSource(productId!, productVersion!);
    }

    final info = SystemInfo(
      serialNumber: serialNumber,
      firmwareVersion: firmwareVersion,
      imei: '',
      model: [
        if (hardwareVersion.isNotEmpty) hardwareVersion,
        if (pnpId.isNotEmpty) 'PNP $pnpId',
      ].join(' · '),
    );
    entity.emit(DeviceInfoUpdated(deviceId: entity.id, info: info));
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete(info);
  }

  @override
  void onData(Uint8List data) {}
}

int? _resolveDeviceSource(int productId, int productVersion) {
  const legacy = <(int, int), int>{
    (94, 256): 224,
    (94, 257): 225,
    (95, 256): 226,
    (95, 257): 227,
    (93, 256): 229,
    (93, 257): 230,
    (105, 257): 242,
    (115, 256): 246,
    (115, 259): 247,
    (116, 257): 251,
    (117, 259): 254,
    (103, 256): 260,
    (103, 257): 261,
    (103, 258): 262,
    (103, 259): 263,
    (103, 260): 264,
    (103, 261): 265,
    (103, 262): 266,
    (63, 256): 414,
    (63, 257): 415,
    (113, 256): 418,
    (113, 257): 419,
  };
  final known = legacy[(productId, productVersion)];
  if (known != null) return known;
  // Newer Gadgetbridge entries encode deviceSource directly as
  // productId:uint16 followed by productVersion:uint16.
  if ((productId == 93 && productVersion >= 258) ||
      productId == 100 ||
      (productId == 103 && productVersion >= 263) ||
      productId >= 120) {
    return (productId << 16) | productVersion;
  }
  return null;
}

class _Reader {
  _Reader(this.bytes, this.offset);

  final Uint8List bytes;
  int offset;

  int get remaining => bytes.length - offset;
  bool get hasRemaining => remaining > 0;

  int readByte() {
    if (!hasRemaining) return 0;
    return bytes[offset++];
  }

  Uint8List readBytes(int length) {
    final end = (offset + length).clamp(offset, bytes.length).toInt();
    final result = Uint8List.sublistView(bytes, offset, end);
    offset = end;
    return result;
  }

  void skip(int length) {
    offset = (offset + length).clamp(offset, bytes.length).toInt();
  }

  String readCString() {
    final start = offset;
    while (offset < bytes.length && bytes[offset] != 0) {
      offset += 1;
    }
    final value = String.fromCharCodes(bytes.sublist(start, offset));
    if (offset < bytes.length) offset += 1;
    return value;
  }
}
