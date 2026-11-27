import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/core/ble_requirement.dart';
import 'package:oronbox/src/device/core/system.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_services_system.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_v3_file_transfer.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_component.dart';

class ZeppOsMusicUploadSystem extends System {
  static const fileTransferEndpoint = 0x000d;
  static const maxFileBytes = 50 * 1024 * 1024;
  static const _firmwareService = '00001530-0000-3512-2118-0009af100700';
  static const _v3Send = BleRequiredCharacteristic(
    serviceUuid: _firmwareService,
    characteristicUuid: '00000023-0000-3512-2118-0009af100700',
    label: 'Zepp OS file transfer v3 send',
  );

  bool _encrypted = false;
  bool _uploading = false;
  int? _version;
  int _chunkSize = 0;
  Set<String> _supportedServices = const {};
  int _nextSession = 0;
  StreamSubscription<Uint8List>? _ackSubscription;
  Completer<void>? _capabilities;
  Completer<int>? _requestAck;
  ZeppOsV3FileTransfer? _transfer;

  ZeppOsDeviceComponent get _component =>
      entity.getRequired<ZeppOsDeviceComponent>();

  int? get _maxWriteLength {
    final transport = entity.transport;
    return transport is CharacteristicTransport
        ? transport.maxWriteLength
        : null;
  }

  Future<void> upload({
    required Uint8List bytes,
    required String filename,
    required String title,
    required String artist,
    void Function(double progress)? onProgress,
  }) async {
    if (_uploading) throw StateError('A music transfer is already in progress');
    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw FormatException('MP3 size must be between 1 byte and 50 MB');
    }
    if (!filename.toLowerCase().endsWith('.mp3')) {
      throw const FormatException('Only MP3 music is supported');
    }
    final cleanTitle = title.trim();
    final cleanArtist = artist.trim();
    if (cleanTitle.isEmpty) throw const FormatException('Title cannot be empty');
    if (cleanArtist.isEmpty) throw const FormatException('Artist cannot be empty');

    _uploading = true;
    try {
      await _initialize();
      final session = _nextSession++ & 0xff;
      // Keep this byte-for-byte compatible with Gadgetbridge. Several Zepp OS
      // firmwares do not URI-decode these two metadata fields.
      final safeTitle = _queryValue(cleanTitle);
      final safeArtist = _queryValue(cleanArtist);
      final url = 'music://file?songName=$safeTitle&singer=$safeArtist&end=1';
      final requestAck = Completer<int>();
      _requestAck = requestAck;
      try {
        await _component.sendToEndpoint(
          fileTransferEndpoint,
          _requestPayload(session, url, filename, bytes),
          encrypted: _encrypted,
          maxWriteLength: _maxWriteLength,
        );
        final existingProgress = await requestAck.future.timeout(
          const Duration(seconds: 15),
        );
        if (existingProgress < 0 || existingProgress > bytes.length) {
          throw StateError('The watch reported an invalid music transfer progress: $existingProgress');
        }
        await _transfer!.send(
          bytes: bytes,
          initialOffset: existingProgress,
          chunkSize: _chunkSize,
          onProgress: onProgress,
        );
        _log.info('music upload completed: $filename, ${bytes.length} bytes');
      } finally {
        if (identical(_requestAck, requestAck)) _requestAck = null;
      }
    } finally {
      _uploading = false;
    }
  }

  Future<void> _initialize() async {
    final transport = entity.transport;
    if (transport is! CharacteristicTransport) {
      throw UnsupportedError('Music upload requires the Zepp OS file transfer channel');
    }
    final servicesSystem = entity.system<ZeppOsServicesSystem>();
    if (servicesSystem == null) {
      throw StateError('Zepp OS service discovery has not been initialized; please reconnect the watch');
    }
    final services = await servicesSystem.fetchSupportedServices();
    if (!services.containsKey(fileTransferEndpoint)) {
      throw UnsupportedError('The watch does not provide a file transfer service');
    }
    _encrypted = services[fileTransferEndpoint] ?? false;
    if (_version == null) {
      final capabilities = Completer<void>();
      _capabilities = capabilities;
      try {
        await _component.sendToEndpoint(
          fileTransferEndpoint,
          Uint8List.fromList(const [0x01]),
          encrypted: _encrypted,
          maxWriteLength: _maxWriteLength,
        );
        await capabilities.future.timeout(const Duration(seconds: 8));
      } finally {
        if (identical(_capabilities, capabilities)) _capabilities = null;
      }
    }
    if (_version != 3) {
      throw UnsupportedError(
        'Music upload requires Zepp OS V3 file transfer, but the watch reported '
        'V${_version ?? 'unknown'}',
      );
    }
    if (!_supportedServices.contains('music')) {
      throw UnsupportedError(
        'The watch\'s file transfer capabilities do not include music, so local '
        'music cannot be uploaded',
      );
    }
    _transfer ??= ZeppOsV3FileTransfer(
      transport: transport,
      characteristic: _v3Send,
      transferLabel: 'music',
    );
    _ackSubscription ??= await transport.subscribeToCharacteristic(
      _v3Send,
      _transfer!.handleAck,
    );
  }

  void handlePayload(Uint8List payload) {
    if (payload.isEmpty) return;
    if (payload[0] == 0x02 && payload.length >= 4) {
      _version = payload[1];
      _chunkSize = ByteData.sublistView(payload).getUint16(2, Endian.little);
      try {
        _supportedServices = _parseSupportedServices(payload);
      } catch (error, stackTrace) {
        final pending = _capabilities;
        if (pending != null && !pending.isCompleted) {
          pending.completeError(error, stackTrace);
        }
        return;
      }
      _log.info(
        'file transfer capabilities: version=$_version, '
        'chunkSize=$_chunkSize, services=$_supportedServices',
      );
      final pending = _capabilities;
      if (_chunkSize <= 0) {
        if (pending != null && !pending.isCompleted) {
          pending.completeError(StateError('The watch reported an invalid music chunk size'));
        }
      } else if (pending != null && !pending.isCompleted) {
        pending.complete();
      }
      return;
    }
    if (payload[0] == 0x04 && payload.length >= 7) {
      final pending = _requestAck;
      if (pending == null || pending.isCompleted) return;
      if (payload[2] != 0) {
        pending.completeError(StateError('The watch refused the music transfer: ${payload[2]}'));
      } else {
        pending.complete(
          ByteData.sublistView(payload).getUint32(3, Endian.little),
        );
      }
    }
  }

  static Uint8List _requestPayload(
    int session,
    String url,
    String filename,
    Uint8List bytes,
  ) {
    final urlBytes = utf8.encode(url);
    final filenameBytes = utf8.encode(filename);
    final payload = Uint8List(
      2 + urlBytes.length + 1 + filenameBytes.length + 1 + 10,
    );
    var offset = 0;
    payload[offset++] = 0x03;
    payload[offset++] = session;
    payload.setRange(offset, offset + urlBytes.length, urlBytes);
    offset += urlBytes.length;
    payload[offset++] = 0;
    payload.setRange(offset, offset + filenameBytes.length, filenameBytes);
    offset += filenameBytes.length;
    payload[offset++] = 0;
    final view = ByteData.sublistView(payload);
    view.setUint32(offset, bytes.length, Endian.little);
    view.setUint32(offset + 4, zeppOsFileCrc32(bytes), Endian.little);
    payload[offset + 8] = 0;
    payload[offset + 9] = 0;
    return payload;
  }

  static String _queryValue(String value) => value
      .replaceAll('&', '＆')
      .replaceAll('=', '＝')
      .replaceAll('?', '？')
      .replaceAll('#', '＃');

  static Set<String> _parseSupportedServices(Uint8List payload) {
    if (payload[1] < 3) return const {};
    if (payload.length < 10) {
      throw const FormatException('File transfer V3 capabilities data is incomplete');
    }
    final count = ByteData.sublistView(payload).getUint16(8, Endian.little);
    var offset = 10;
    final result = <String>{};
    for (var index = 0; index < count; index++) {
      final end = payload.indexOf(0, offset);
      if (end < 0) {
        throw const FormatException('File transfer capability name is missing its terminator');
      }
      result.add(utf8.decode(payload.sublist(offset, end)));
      offset = end + 1;
    }
    return Set.unmodifiable(result);
  }

  @override
  void onData(Uint8List data) {}

  @override
  Future<void> dispose() async {
    await _ackSubscription?.cancel();
    _ackSubscription = null;
  }
}

final Logger _log = getLogger('ZeppOsMusicUploadSystem');
