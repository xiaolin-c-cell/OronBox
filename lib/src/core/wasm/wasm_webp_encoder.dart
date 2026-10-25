import 'dart:typed_data';

/// libwebp WASM 编码器的 iOS 桩（原因见 wasm_runtime.dart 顶部说明）。
///
/// [encode] 恒返回 null——这正是调用方既有的"编码失败回退 PNG"信号，
/// 表盘图片处理链路因此保持完整、只是退化为 PNG。
final class WasmWebpEncoder {
  WasmWebpEncoder._();

  static const assetPath = 'assets/wasm/webp_encoder.wasm';

  static final Future<WasmWebpEncoder> _shared =
      Future.value(WasmWebpEncoder._());

  static Future<WasmWebpEncoder> instance() => _shared;

  /// Creates an encoder from bytes already loaded by another isolate.
  static Future<WasmWebpEncoder> fromBytes(Uint8List bytes) async =>
      WasmWebpEncoder._();

  Uint8List? encode(
    Uint8List rgba,
    int width,
    int height,
    {double quality = 75}
  ) => null;

  void dispose() {}
}
