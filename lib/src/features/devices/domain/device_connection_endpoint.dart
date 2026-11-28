import 'package:flutter/foundation.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/device/core/connect_type.dart';
import 'package:oronbox/src/device/core/device_profile.dart';
import 'package:oronbox/src/device/xiaomi/xiaomi_device_catalog.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_catalog.dart';
import 'package:oronbox/src/features/devices/utils/device_address.dart';

typedef DeviceConnectionEndpoint = ({String addr, String name});

final _classicAddressPattern = RegExp(
  r'^[0-9a-fA-F]{2}([:-][0-9a-fA-F]{2}){5}$',
);

bool _isClassicAddress(String value) =>
    _classicAddressPattern.hasMatch(value.trim());

/// Resolves the physical endpoint used to connect a device card.
///
/// A saved device owns an exact address/transport pair. Scanned endpoints are
/// consulted when a device needs a different transport or when a BLE-only
/// identifier must be paired with its classic SPP endpoint.
DeviceConnectionEndpoint? resolveDeviceConnectionEndpoint({
  required MiWearState device,
  required bool saved,
  required String connectType,
  required List<BTDeviceInfo> scannedDevices,
}) {
  final normalizedType = connectType.toLowerCase();
  final hasClassicAddress = _isClassicAddress(device.addr);

  // iOS 上 BLE 只能用 CoreBluetooth 的 UUID 连接，不能拿经典蓝牙 MAC。
  // 若设备记录里是 MAC（历史上以 SPP 配对过），必须先到扫描结果里
  // 找同名 BLE 端点，否则会把 MAC 直接喂给 GATT，连接必定失败。
  final needsIosBleAddressRemap =
      isIosBleOnly &&
      normalizedType == ConnectType.ble.name &&
      hasClassicAddress;

  if (!needsIosBleAddressRemap &&
      device.connectType.toLowerCase() == normalizedType &&
      !(normalizedType == ConnectType.spp.name && !hasClassicAddress)) {
    return (addr: device.addr, name: device.name);
  }

  if (needsIosBleAddressRemap) {
    final wantName = device.name.trim();
    final wantIdentity =
        xiaomiWearableIdentityForCodename(device.codename) ??
        normalizeXiaomiWearableIdentity(device.name);
    for (final endpoint in scannedDevices) {
      if (endpoint.connectType.toLowerCase() != ConnectType.ble.name) continue;
      final sameName = endpoint.name.trim() == wantName;
      final sameIdentity =
          wantIdentity != null &&
          (normalizeXiaomiWearableIdentity(endpoint.name)?.codename ==
              wantIdentity.codename);
      if (!sameName && !sameIdentity) continue;
      return (addr: endpoint.addr, name: endpoint.name);
    }
    // 扫不到对应的 BLE 端点时返回 null，由 UI 提示「端点不可用」，
    // 好过把经典 MAC 喂给 GATT 后静默超时。
    return null;
  }

  final sourceIdentity = zeppOsDeviceForBluetoothName(device.name);
  if (sourceIdentity == null) {
    final profile = DeviceRegistry.resolveIdentity(
      name: device.name,
      codename: device.codename,
    );
    if (profile.id == DeviceRegistry.unknown.id) return null;

    // A BLE scan on Apple platforms exposes a CoreBluetooth UUID, while the
    // VelaOS transport must use the classic SPP address. When the user opens
    // a scanned Xiaomi BLE card and switches to SPP, resolve the matching
    // classic endpoint by the catalog identity instead of forwarding the BLE
    // UUID to the RFCOMM driver.
    if (normalizedType == ConnectType.spp.name) {
      final xiaomiIdentity =
          xiaomiWearableIdentityForCodename(device.codename) ??
          normalizeXiaomiWearableIdentity(device.name);
      if (xiaomiIdentity != null) {
        for (final endpoint in scannedDevices) {
          if (endpoint.connectType.toLowerCase() != ConnectType.spp.name) {
            continue;
          }
          final endpointIdentity = normalizeXiaomiWearableIdentity(
            endpoint.name,
          );
          if (endpointIdentity?.codename == xiaomiIdentity.codename) {
            return (
              addr: formatDeviceAddress(endpoint.addr),
              name: endpoint.name,
            );
          }
        }
      }
    }

    for (final endpoint in scannedDevices) {
      if (deviceAddressEquals(endpoint.addr, device.addr)) {
        if (normalizedType == ConnectType.spp.name &&
            !_isClassicAddress(endpoint.addr)) {
          continue;
        }
        return (addr: formatDeviceAddress(endpoint.addr), name: endpoint.name);
      }
    }
    return null;
  }
  for (final endpoint in scannedDevices) {
    if (endpoint.connectType.toLowerCase() != normalizedType) continue;
    final candidateIdentity = zeppOsDeviceForBluetoothName(endpoint.name);
    if (candidateIdentity?.id == sourceIdentity.id) {
      return (addr: endpoint.addr, name: endpoint.name);
    }
  }

  if (saved &&
      normalizedType == ConnectType.spp.name &&
      sourceIdentity.connectionCapability != ZeppOsConnectionCapability.ble) {
    return (addr: device.addr, name: device.name);
  }
  return null;
}

/// iOS 上第三方 App 无法使用经典蓝牙 SPP（iOS 12+ 限制）。
bool get isIosBleOnly =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
