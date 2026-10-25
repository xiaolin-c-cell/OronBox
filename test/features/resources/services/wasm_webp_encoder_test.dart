import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:oronbox/src/core/wasm/wasm_webp_encoder.dart';
import 'package:oronbox/src/features/resources/services/resource_image_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('indexed PNG pixels are expanded to RGBA before WebP encoding', () {
    final palette = img.PaletteUint8(2, 4)
      ..setRgba(0, 12, 34, 56, 255)
      ..setRgba(1, 210, 180, 90, 128);
    final indexed =
        img.Image(
            width: 2,
            height: 1,
            numChannels: 1,
            withPalette: true,
            palette: palette,
          )
          ..setPixelIndex(0, 0, 0)
          ..setPixelIndex(1, 0, 1);
    final decoded = img.decodePng(img.encodePng(indexed));
    expect(decoded, isNotNull);

    expect(
      materializeResourceImageRgba(decoded!),
      Uint8List.fromList([12, 34, 56, 255, 210, 180, 90, 128]),
    );
  });

  // iOS 桩契约：wasm_run_flutter 没有可链接的 iOS 原生库（见
  // wasm_runtime.dart 顶部说明），encode() 恒返回 null，调用方据此回退 PNG。
  test('WasmWebpEncoder stub signals failure so callers fall back to PNG',
      () async {
    final encoder = await WasmWebpEncoder.instance();
    addTearDown(encoder.dispose);

    final rgba = Uint8List.fromList([12, 34, 56, 255, 210, 180, 90, 128]);
    expect(encoder.encode(rgba, 2, 1), isNull);
    expect(encoder.encode(rgba, 2, 1, quality: 90), isNull);

    final fromBytes = await WasmWebpEncoder.fromBytes(rgba);
    expect(fromBytes.encode(rgba, 2, 1), isNull);
  });
}
