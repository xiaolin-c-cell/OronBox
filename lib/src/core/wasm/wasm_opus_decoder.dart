import 'dart:typed_data';

import 'package:oronbox/src/core/wasm/wasm_runtime.dart';

/// libopus WASM 解码器的 iOS 桩（原因见 wasm_runtime.dart 顶部说明）。
/// 仅 ZeppOS 小爱语音页使用，与小米手环主链路无关。
final class WasmOpusDecoder {
  WasmOpusDecoder._();

  static Future<WasmOpusDecoder> create({
    int sampleRate = 16000,
    int channels = 1,
  }) async {
    if (channels != 1) {
      throw ArgumentError.value(
        channels,
        'channels',
        'only mono is supported',
      );
    }
    throw UnsupportedError(
      'libopus WASM decoder is unavailable in this build '
      '(wasm_run_flutter has no linkable iOS native library)',
    );
  }

  Float32List decode(Uint8List packet) => throw UnsupportedError(
    'libopus WASM decoder is unavailable in this build',
  );

  void dispose() {}
}
