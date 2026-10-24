import 'package:oronbox/src/core/wasm/wasm_runtime.dart';
import 'package:oronbox/src/features/plugins/storage/plugin_storage.dart';

/// WASI 沙箱的 iOS 桩（原因见 core/wasm/wasm_runtime.dart 顶部说明）。
/// 仅被 WASM 插件运行时与 PluginWasmHost 使用，二者在 iOS 上均不可用。
final class PluginWasiSandbox {
  PluginWasiSandbox._({
    required this.pluginId,
    required this.storage,
    required this.config,
  });

  final String pluginId;
  final PluginStorage storage;
  final WasiConfig config;

  static Future<PluginWasiSandbox> create({
    required String pluginId,
    required PluginStorage storage,
  }) async => throw UnsupportedError(
    'WASM plugin runtime is unavailable in this build '
    '(wasm_run_flutter has no linkable iOS native library)',
  );

  Future<void> sync() async {}
}
