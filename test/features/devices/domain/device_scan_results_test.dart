import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/bluetooth_platform.dart';
import 'package:oronbox/src/device/core/connect_type.dart';
import 'package:oronbox/src/device/core/device_profile.dart';
import 'package:oronbox/src/features/devices/domain/device_scan_results.dart';

void main() {
  test('BLE replaces speculative SPP duplicate with the same Android MAC', () {
    final profile = DeviceRegistry.resolveIdentity(name: 'REDMI Watch 5');
    final spp = mergeScannedDeviceEndpoint(
      const [],
      const BluetoothEndpoint(
        name: 'REDMI Watch 5',
        address: 'AA:BB:CC:DD:EE:FF',
        connectType: ConnectType.spp,
      ),
      displayName: 'REDMI Watch 5',
      profile: profile,
    );
    final merged = mergeScannedDeviceEndpoint(
      spp,
      const BluetoothEndpoint(
        name: 'REDMI Watch 5',
        address: 'aa:bb:cc:dd:ee:ff',
        connectType: ConnectType.ble,
      ),
      displayName: 'REDMI Watch 5',
      profile: profile,
    );

    expect(merged, hasLength(1));
    expect(merged.single.connectType, 'ble');
    expect(merged.single.addr, 'AA:BB:CC:DD:EE:FF');
  });

  test('speculative SPP duplicate cannot replace an existing BLE result', () {
    final profile = DeviceRegistry.resolveIdentity(name: 'REDMI Watch 5');
    final ble = mergeScannedDeviceEndpoint(
      const [],
      const BluetoothEndpoint(
        name: 'REDMI Watch 5',
        address: 'AA:BB:CC:DD:EE:FF',
        connectType: ConnectType.ble,
      ),
      displayName: 'REDMI Watch 5',
      profile: profile,
    );
    final merged = mergeScannedDeviceEndpoint(
      ble,
      const BluetoothEndpoint(
        name: 'REDMI Watch 5',
        address: 'aa-bb-cc-dd-ee-ff',
        connectType: ConnectType.spp,
      ),
      displayName: 'REDMI Watch 5',
      profile: profile,
    );

    expect(merged, same(ble));
    expect(merged.single.connectType, 'ble');
  });

  test('Zepp OS keeps independently selectable BLE and BTBR endpoints', () {
    final profile = DeviceRegistry.resolveIdentity(name: 'Active 2 (Round)');
    final ble = mergeScannedDeviceEndpoint(
      const [],
      const BluetoothEndpoint(
        name: 'Active 2 (Round)',
        address: 'AA:BB:CC:DD:EE:FF',
        connectType: ConnectType.ble,
      ),
      displayName: 'Active 2 (Round)',
      profile: profile,
    );
    final merged = mergeScannedDeviceEndpoint(
      ble,
      const BluetoothEndpoint(
        name: 'Active 2 (Round)',
        address: 'AA:BB:CC:DD:EE:FF',
        connectType: ConnectType.spp,
      ),
      displayName: 'Active 2 (Round)',
      profile: profile,
    );

    expect(
      merged.map((device) => device.connectType),
      containsAll(['ble', 'spp']),
    );
  });
}
