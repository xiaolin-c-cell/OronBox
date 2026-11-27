import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';

/// The single seam used by GUI feature adapters
///
/// Desktop resolves to an IPC client and mobile resolves to an in-process
/// host. Feature code must not branch on the platform
final applicationHostProvider = Provider<OronBoxCommandBus>((ref) {
  return const _UnavailableApplicationHost();
});

class _UnavailableApplicationHost implements OronBoxCommandBus {
  const _UnavailableApplicationHost();

  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(OronBoxCommand command) async =>
      const CommandResult.failure(
        CommandError('host_unavailable', 'Application host is not configured'),
      );

  @override
  Future<void> close() async {}
}
