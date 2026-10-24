import 'dart:async';
import 'dart:typed_data';

import 'package:oronbox/src/features/plugins/storage/plugin_storage.dart';

import 'plugin_runtime.dart';

/// WASM 插件运行时的 iOS 桩（原因见 core/wasm/wasm_runtime.dart 顶部说明）。
///
/// WASM 插件在 iOS 上不可用：[start] 抛 UnsupportedError，插件管理器会
/// 按既有错误路径向用户展示失败原因。QuickJS 插件走另一套运行时，不受影响。
final class WasmPluginRuntime implements PluginRuntime {
  WasmPluginRuntime({required this.storage});

  final PluginStorage storage;

  @override
  Map<String, Object?> get diagnostics => const {
    'engine': 'wasm_run',
    'running': false,
    'pendingRequests': 0,
    'instantiated': false,
    'unavailable': true,
  };

  @override
  Future<void> start({
    required String pluginId,
    required String pluginName,
    required String pluginVersion,
    required String runtimeVersion,
    required Uint8List entryBytes,
    required String bootstrap,
    required PluginHostCall hostCall,
  }) async => throw UnsupportedError(
    'WASM plugin runtime is unavailable in this build '
    '(wasm_run_flutter has no linkable iOS native library)',
  );

  @override
  Future<void> invokeCallback(String callbackId, [Object? value]) async {}

  @override
  Future<Object?> invokeRegistered(
    String callbackId,
    List<Object?> arguments,
  ) async => null;

  @override
  Future<void> dispatchEvent(String name, String payload) async {}

  @override
  Future<void> close() async {}
}
