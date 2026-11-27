import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The useful part of a Xiaomi device log archive is the current run log.
/// Keep this parser deliberately read-only: device supplied paths must never
/// be written back to disk or treated as filesystem paths.
Uint8List? extractCurrentDeviceLog(List<int> archiveBytes) {
  if (archiveBytes.length < 2) return null;
  try {
    final decoded = archiveBytes[0] == 0x1f && archiveBytes[1] == 0x8b
        ? GZipDecoder().decodeBytes(archiveBytes)
        : archiveBytes;
    final archive =
        decoded.length >= 2 && decoded[0] == 0x50 && decoded[1] == 0x4b
        ? ZipDecoder().decodeBytes(decoded, verify: true)
        : TarDecoder().decodeBytes(decoded);
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final normalized = entry.name.replaceAll('\\', '/').toLowerCase();
      if (normalized == 'offlinelog/tmp.log' ||
          normalized.endsWith('/offlinelog/tmp.log')) {
        return entry.readBytes();
      }
    }
  } catch (_) {
    // The archive is still useful to the caller even when a firmware variant
    // uses an unsupported container.  Extraction is an optional companion.
  }
  return null;
}
