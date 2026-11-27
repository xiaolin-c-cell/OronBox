import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/features/devices/domain/device_connection_endpoint.dart';

void main() {
  test('a newly scanned Xiaomi BLE endpoint can use its SPP transport', () {
    const scanned = BTDeviceInfo(
      name: 'Xiaomi Smart Band 9 Pro',
      addr: 'D4:17:61:14:18:6E',
      connectType: 'ble',
    );

    final endpoint = resolveDeviceConnectionEndpoint(
      device: const MiWearState(
        name: 'Xiaomi Smart Band 9 Pro',
        addr: 'D4:17:61:14:18:6E',
        connectType: 'ble',
        codename: 'n67',
      ),
      saved: false,
      connectType: 'spp',
      scannedDevices: const [scanned],
    );

    expect(endpoint, isNotNull);
    expect(endpoint!.addr, 'D4:17:61:14:18:6E');
  });

  test('a Xiaomi BLE UUID resolves to the matching classic SPP endpoint', () {
    const scannedBle = BTDeviceInfo(
      name: 'Xiaomi Smart Band 10',
      addr: '09998A62-3FB0-433A-7CEB-72D157F438FC',
      connectType: 'ble',
    );
    const scannedSpp = BTDeviceInfo(
      name: 'Xiaomi Smart Band 10',
      addr: 'AA:BB:CC:DD:EE:FF',
      connectType: 'spp',
    );

    final endpoint = resolveDeviceConnectionEndpoint(
      device: const MiWearState(
        name: 'Xiaomi Smart Band 10',
        addr: '09998A62-3FB0-433A-7CEB-72D157F438FC',
        connectType: 'spp',
      ),
      saved: false,
      connectType: 'spp',
      scannedDevices: const [scannedBle, scannedSpp],
    );

    expect(
      endpoint,
      (addr: 'AA:BB:CC:DD:EE:FF', name: 'Xiaomi Smart Band 10'),
    );
  });

  test('a BLE UUID is never forwarded as a Xiaomi SPP endpoint', () {
    final endpoint = resolveDeviceConnectionEndpoint(
      device: const MiWearState(
        name: 'Xiaomi Smart Band 10',
        addr: '09998A62-3FB0-433A-7CEB-72D157F438FC',
        connectType: 'spp',
      ),
      saved: false,
      connectType: 'spp',
      scannedDevices: const [
        BTDeviceInfo(
          name: 'Xiaomi Smart Band 10',
          addr: '09998A62-3FB0-433A-7CEB-72D157F438FC',
          connectType: 'ble',
        ),
      ],
    );

    expect(endpoint, isNull);
  });
}
