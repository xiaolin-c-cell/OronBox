/// Compares the raw certificate fingerprint exchanged by XMS.
///
/// Vela sends a byte array, so comparison must be length-sensitive and must
/// not treat a hex string, a SHA-256 digest, or a prefix as equivalent.
bool xmsFingerprintsMatch(Iterable<int> expected, Iterable<int> supplied) {
  final left = expected.toList(growable: false);
  final right = supplied.toList(growable: false);
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
