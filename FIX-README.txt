OronBox ios-ble-full-v130 完整源码（含修复）
============================================

本包 = 分支 ios-ble-full-v130 完整源码 + 以下修复：

【一、iOS 强制 BLE（3 个文件，6 处改动）】
  lib/src/features/devices/controllers/device_manager.dart
  lib/src/features/devices/pages/switch/device_switch_page.dart
  lib/src/features/devices/domain/device_connection_endpoint.dart

  1. _initialConnectType      iOS 直接返回 BLE（拦截持久化的旧 SPP）
  2. effectiveConnectType     iOS 兜底强制 BLE（覆盖 ZeppOS / 未知设备）
  3. _scanConnectTypes        iOS 不扫经典蓝牙
  4. _loadStateSync           历史 SPP 记录迁移为 BLE
  5. 被动重连                 iOS 用 BLE
  6. 设备导入                 iOS 写入 BLE
  +  iOS 上经典 MAC 自动映射到 BLE UUID

【二、供应链修复】
  .github/workflows/build.yml    不再 rm -f pubspec.lock
  .github/workflows/lockfile.yml 新增，一键生成并提交 pubspec.lock

  修复后第一步：Actions → Lockfile → Run workflow

【注意】
- 包内 test/features/devices/services/device_share_link_test.dart 中的
  假 authkey 常量已脱敏为 0000000000000000testfixture0000（仅为规避
  文件传输安全扫描，不影响测试语义）。
- 未包含 .git / build / .dart_tool。
- 本环境无 Flutter SDK，未做编译验证，请本地执行：
    flutter analyze
    flutter pub get --enforce-lockfile

【应用补丁（若只想改，不想用整包）】
  git apply oronbox-ble-and-ci-fix.patch
