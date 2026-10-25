/// 蓝牙子系统结构化日志通道。
///
/// 设计目标（iOS / 桌面排障）：
/// - 所有事件走 [logDiagnostic]，携带 machine-readable fields，诊断流与
///   日志文件都能按字段检索；
/// - AUTHKEY 等敏感值只记录长度 + sha256 指纹（[redactAuthKey]），原文绝不
///   入日志——导出的日志 zip 常被用户直接分享，泄露 key 等于泄露手环绑定；
/// - 包级日志（[btPacket]）只记前若干字节的 hex 预览，防止日志量爆炸。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';

final _log = getLogger('bluetooth');
final _packetLog = getLogger('bluetooth.packet');

/// 需要放行 FINE 级别的蓝牙相关 channel。logging 包的 hierarchical level：
/// 子 channel 设置了自己的 level 就会覆盖 root 的 INFO。
const bluetoothChannelNames = <String>[
  'oronbox.bluetooth',
  'oronbox.bluetooth.packet',
  'oronbox.BleConnection',
  'oronbox.BleGattDriver',
  'oronbox.BluetoothPlatform',
];

/// 打开蓝牙 channel 的 FINE 级别。必须在 [initLogging] 之后调用。
void initBluetoothLogging() {
  // logging 1.3：给非 root logger 设置 level 前必须先打开全局
  // hierarchicalLoggingEnabled 开关（默认 false，否则 setter 直接抛
  // UnsupportedError——iOS 白屏的根因就是这里）。打开后 logger.level
  // getter 也会沿父链解析，与 logDiagnostic 的阈值比较逻辑一致。
  hierarchicalLoggingEnabled = true;
  for (final name in bluetoothChannelNames) {
    Logger(name).level = Level.FINE;
  }
  logDiagnostic(_log, Level.INFO, 'bluetooth logging initialized', fields: {
    'channels': bluetoothChannelNames.length,
    'level': 'FINE',
  });
}

/// AUTHKEY 脱敏：只暴露长度与 sha256 前 8 位指纹。
String redactAuthKey(String? authKeyHex) {
  if (authKeyHex == null || authKeyHex.isEmpty) return 'absent';
  final fingerprint =
      sha256.convert(utf8.encode(authKeyHex)).toString().substring(0, 8);
  return 'len=${authKeyHex.length} fp=$fingerprint';
}

/// 字节内容的 hex 预览，默认只显示前 16 字节。
String hexPreview(Uint8List data, {int maxBytes = 16}) {
  if (data.isEmpty) return '(empty)';
  final shown = data.length <= maxBytes ? data : data.sublist(0, maxBytes);
  final hex = shown
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join(' ');
  return data.length <= maxBytes ? hex : '$hex (+${data.length - maxBytes}B)';
}

void btScanStart({
  List<String> serviceUuids = const [],
  List<String> namePrefixes = const [],
  List<String> connectTypes = const [],
  int timeoutMs = 0,
}) => logDiagnostic(_log, Level.INFO, 'BLE scan started', fields: {
  'serviceUuids': serviceUuids.isEmpty ? 'any' : serviceUuids.join(','),
  'namePrefixes': namePrefixes.isEmpty ? 'any' : namePrefixes.join(','),
  'connectTypes': connectTypes.isEmpty ? 'any' : connectTypes.join(','),
  'timeoutMs': timeoutMs,
});

void btScanStopped({required int deviceCount, required int elapsedMs}) =>
    logDiagnostic(_log, Level.INFO, 'BLE scan stopped', fields: {
      'deviceCount': deviceCount,
      'elapsedMs': elapsedMs,
    });

void btDeviceDiscovered({
  required String address,
  required String name,
  int? rssi,
  List<String> serviceUuids = const [],
}) => logDiagnostic(_log, Level.FINE, 'BLE device discovered', fields: {
  'address': address,
  'name': name,
  'rssi': rssi ?? 'unknown',
  'serviceUuids': serviceUuids.isEmpty ? 'none' : serviceUuids.join(','),
});

void btConnectAttempt({
  required String deviceId,
  required String deviceName,
  String transport = 'ble',
  bool attemptPair = true,
  int? desiredMtu,
}) => logDiagnostic(_log, Level.INFO, 'BLE connect attempt', fields: {
  'deviceId': deviceId,
  'deviceName': deviceName,
  'transport': transport,
  'attemptPair': attemptPair,
  'desiredMtu': desiredMtu ?? 23,
});

void btConnectEstablished({
  required String deviceId,
  required int mtu,
  required int serviceCount,
  required int elapsedMs,
}) => logDiagnostic(_log, Level.INFO, 'BLE connection established', fields: {
  'deviceId': deviceId,
  'mtu': mtu,
  'serviceCount': serviceCount,
  'elapsedMs': elapsedMs,
});

void btConnectFailed({
  required String deviceId,
  required String stage,
  required Object error,
  int? elapsedMs,
}) => logDiagnostic(_log, Level.SEVERE, 'BLE connect failed', fields: {
  'deviceId': deviceId,
  'stage': stage,
  if (elapsedMs != null) 'elapsedMs': elapsedMs,
}, error: error);

void btDisconnected({required String deviceId, String? reason}) =>
    logDiagnostic(_log, Level.WARNING, 'BLE connection lost', fields: {
      'deviceId': deviceId,
      'reason': reason ?? 'unspecified',
    });

void btNotify({
  required String deviceId,
  required String charUuid,
  required bool subscribed,
}) => logDiagnostic(_log, Level.INFO, 'BLE notification state', fields: {
  'deviceId': deviceId,
  'char': charUuid,
  'subscribed': subscribed,
});

void btWrite({
  required String deviceId,
  required String charUuid,
  required int byteCount,
  required bool withResponse,
}) => logDiagnostic(_log, Level.FINE, 'BLE write', fields: {
  'deviceId': deviceId,
  'char': charUuid,
  'bytes': byteCount,
  'withResponse': withResponse,
});

void btRecv({
  required String deviceId,
  required String charUuid,
  required int byteCount,
}) => logDiagnostic(_packetLog, Level.FINE, 'BLE notification data', fields: {
  'deviceId': deviceId,
  'char': charUuid,
  'bytes': byteCount,
});

void btPacket({
  required String direction,
  required String deviceId,
  String? charUuid,
  required Uint8List data,
}) => logDiagnostic(_packetLog, Level.FINE, 'packet $direction', fields: {
  'deviceId': deviceId,
  if (charUuid != null) 'char': charUuid,
  'len': data.length,
  'hex': hexPreview(data),
});

void btAuthStage({
  required String stage,
  bool ok = true,
  String? keyFingerprint,
  Object? error,
}) => logDiagnostic(
  _log,
  ok ? Level.INFO : Level.WARNING,
  'auth $stage',
  fields: {
    'stage': stage,
    'ok': ok,
    if (keyFingerprint != null) 'key': keyFingerprint,
    if (error != null) 'error': error.toString(),
  },
);
