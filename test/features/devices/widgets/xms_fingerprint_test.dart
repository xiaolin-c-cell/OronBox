import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/devices/widgets/xms_fingerprint.dart';

void main() {
  test('matches the exact raw Vela fingerprint bytes', () {
    final fingerprint = List<int>.generate(20, (index) => index);

    expect(xmsFingerprintsMatch(fingerprint, [...fingerprint]), isTrue);
    expect(xmsFingerprintsMatch(fingerprint, [...fingerprint, 20]), isFalse);
    expect(
      xmsFingerprintsMatch(fingerprint, [...fingerprint]..[19] = 255),
      isFalse,
    );
  });
}
