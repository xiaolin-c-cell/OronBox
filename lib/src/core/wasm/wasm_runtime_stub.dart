// Dart-only stub used on platforms where the wasm_abp native library is not
// available (notably iOS). Provides the same public surface as
// wasm_runtime_io.dart but fails clearly at runtime instead of requiring a
// bundled native library that does not exist for the target architecture.

import 'dart:typed_data';

import 'wasm_compatibility.dart';

final class WasmRuntime {
  WasmRuntime({WasmCompatibility? compatibility})
    : _compatibility = compatibility ?? WasmCompatibility.shared;

  final WasmCompatibility _compatibility;

  static final WasmRuntime shared = WasmRuntime();
  Map<String, Object?> get diagnostics => const {'engine': 'unavailable'};

  WasmScope openScope(String owner) => WasmScope._(this, owner);
}

final class WasmScope {
  WasmScope._(this._runtime, this.owner);

  final WasmRuntime _runtime;
  final String owner;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  Future<ScopedWasmInstance> instantiateAsset(String assetPath) async {
    throw UnsupportedError(
      'WebAssembly runtime is not available on this platform',
    );
  }

  Future<ScopedWasmInstance> instantiate(
    Uint8List bytes, {
    bool withWasi = true,
    Map<String, String> preopens = const {},
  }) async {
    throw UnsupportedError(
      'WebAssembly runtime is not available on this platform',
    );
  }

  void dispose() {
    _disposed = true;
  }

  void _ensureActive() {
    if (_disposed) throw StateError('WASM scope "$owner" is disposed');
  }
}

final class ScopedWasmInstance {
  ScopedWasmInstance._(this._onDispose);

  final void Function() _onDispose;
  bool _disposed = false;

  List<int> call(String name, [List<int> arguments = const []]) {
    throw UnsupportedError(
      'WebAssembly runtime is not available on this platform',
    );
  }

  Future<List<num>> callNumbersAsync(String name, List<num> arguments) async {
    throw UnsupportedError(
      'WebAssembly runtime is not available on this platform',
    );
  }

  WasmMemoryView memory([String name = 'memory']) {
    throw UnsupportedError(
      'WebAssembly runtime is not available on this platform',
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _onDispose();
  }

  void _ensureActive() {
    if (_disposed) throw StateError('WASM instance is disposed');
  }
}

final class WasmMemoryView {
  WasmMemoryView._();

  Uint8List read(int offset, int length) {
    throw UnsupportedError(
      'WebAssembly runtime is not available on this platform',
    );
  }

  void write(int offset, Uint8List data) {
    throw UnsupportedError(
      'WebAssembly runtime is not available on this platform',
    );
  }
}
