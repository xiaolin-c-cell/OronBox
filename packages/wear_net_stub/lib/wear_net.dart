// Pure-Dart stub of wear_net for iOS builds.
// wear_net needs a native TUN/network-extension backend that third-party iOS
// apps cannot use; XiaomiNetworkSystem already degrades gracefully when
// WearNetSession.open() throws UnsupportedError.

import 'dart:typed_data';

sealed class WearNetEvent {
  const WearNetEvent();
}

class WearNetStatus extends WearNetEvent {
  const WearNetStatus(this.message);
  final String message;
}

class WearNetWarning extends WearNetEvent {
  const WearNetWarning(this.message);
  final String message;
}

class WearNetStatistics extends WearNetEvent {
  const WearNetStatistics({
    this.rxBytes = 0,
    this.txBytes = 0,
    this.sessions = 0,
  });
  final int rxBytes;
  final int txBytes;
  final int sessions;
}

class WearNetPacket extends WearNetEvent {
  const WearNetPacket(this.payload);
  final Uint8List payload;
}

class WearNetClosed extends WearNetEvent {
  const WearNetClosed();
}

class WearNetSession {
  WearNetSession._();

  static Future<WearNetSession> open() => Future.error(
    const UnsupportedError('Network proxy is unavailable on this platform'),
  );

  Stream<Uint8List> get outboundPackets => const Stream<Uint8List>.empty();
  Stream<WearNetEvent> get events => const Stream.empty();

  void pushInbound(List<int> packet) {
    throw const UnsupportedError('Network proxy is unavailable on this platform');
  }

  Future<void> close() async {}
}
