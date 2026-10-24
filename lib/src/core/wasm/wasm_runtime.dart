/// iOS 构建的 WASM 运行时桩。
///
/// 上游 wasm_run_flutter 的 iOS 原生资产是裸 dylib，无法被 Flutter 工具链
/// 嵌入 iOS app（Xcode 链接期 wasm_run 符号全部缺失，链接直接失败）。
/// 因此 iOS 版本移除 wasm_run_flutter 依赖；本文件保留原 API 形状，
/// 所有入口抛 UnsupportedError，调用方按既有错误路径降级。
library;

import 'dart:async';
import 'dart:typed_data';

const _kWasmUnavailable =
    'WASM runtime is unavailable in this build (wasm_run_flutter has no '
    'linkable iOS native library; the dependency was removed for iOS)';

enum ValueTy { i32, i64, f32, f64 }

final class WasmFunction {
  const WasmFunction();

  List<Object?> call(List<Object?> arguments) =>
      throw UnsupportedError(_kWasmUnavailable);
}

final class WasmInstanceBuilder {
  WasmInstanceBuilder addImport(
    String module,
    String name,
    WasmFunction function,
  ) => this;
}

typedef WasmInstanceConfigurator = void Function(WasmInstanceBuilder builder);

final class WasiConfig {
  const WasiConfig({
    this.preopenedDirs = const [],
    this.webBrowserFileSystem = const {},
    this.captureStdout = false,
    this.captureStderr = false,
  });

  final List<PreopenedDir> preopenedDirs;
  final Map<String, WasiDirectory> webBrowserFileSystem;
  final bool captureStdout;
  final bool captureStderr;
}

final class PreopenedDir {
  const PreopenedDir({required this.wasmGuestPath, required this.hostPath});

  final String wasmGuestPath;
  final String hostPath;
}

abstract class WasiFd {}

final class WasiFile extends WasiFd {
  WasiFile(this.content);

  final Uint8List content;
}

final class WasiDirectory extends WasiFd {
  WasiDirectory(this.items);

  final Map<String, WasiFd> items;
}

final class WasmRuntime {
  WasmRuntime._();

  static final WasmRuntime shared = WasmRuntime._();

  WasmScope openScope(String owner) => WasmScope._();
}

final class WasmScope {
  WasmScope._();

  Future<ScopedWasmInstance> instantiateAsset(
    String assetPath, {
    WasmInstanceConfigurator? configure,
    WasiConfig? wasiConfig,
  }) async => throw UnsupportedError(_kWasmUnavailable);

  Future<ScopedWasmInstance> instantiate(
    Uint8List bytes, {
    String? cacheKey,
    WasmInstanceConfigurator? configure,
    WasiConfig? wasiConfig,
  }) async => throw UnsupportedError(_kWasmUnavailable);

  void dispose() {}
}

final class WasmMemory {
  WasmMemory._();

  Uint8List get view => throw UnsupportedError(_kWasmUnavailable);
}

final class ScopedWasmInstance {
  ScopedWasmInstance._();

  Stream<Uint8List> get stdout => const Stream<Uint8List>.empty();
  Stream<Uint8List> get stderr => const Stream<Uint8List>.empty();

  WasmFunction function(String name) => throw UnsupportedError(_kWasmUnavailable);

  WasmFunction? functionOrNull(String name) =>
      throw UnsupportedError(_kWasmUnavailable);

  WasmMemory memory(String name) => throw UnsupportedError(_kWasmUnavailable);

  List<Object?> call(String name, [List<Object?> arguments = const []]) =>
      throw UnsupportedError(_kWasmUnavailable);

  void dispose() {}
}
