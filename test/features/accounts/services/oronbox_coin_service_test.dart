import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/features/accounts/services/oronbox_coin_service.dart';

void main() {
  test('coin operations stay behind the application host', () async {
    final host = _CoinHost();
    final service = OronBoxCoinService(host);

    expect((await service.account()).balanceUnits, 12);
    expect((await service.checkin()).reward, 3);
    await service.coin('resource/id', 2);

    expect(host.methods, ['coins.account', 'coins.checkin', 'coins.resource']);
    expect(host.lastParams, {'resource': 'resource/id', 'coins': 2});
  });

  test('reads the number of coins already given to a resource', () async {
    final host = _CoinHost();
    final service = OronBoxCoinService(host);

    expect(await service.myCoins('resource/id'), 1);
    expect(host.methods, ['coins.resource.status']);
    expect(host.lastParams, {'resource': 'resource/id'});
  });

  test('preserves host error codes', () async {
    final service = OronBoxCoinService(
      _CoinHost(
        failure: const CommandError(
          'invalid_refresh_token',
          'refresh token is invalid or expired',
        ),
      ),
    );

    await expectLater(
      service.account(),
      throwsA(
        isA<CoinCommandException>().having(
          (error) => error.code,
          'code',
          'invalid_refresh_token',
        ),
      ),
    );
  });
}

class _CoinHost implements OronBoxCommandBus {
  _CoinHost({this.failure});

  final CommandError? failure;
  final methods = <String>[];
  Map<String, Object?> lastParams = const {};

  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    methods.add(command.method);
    lastParams = command.params;
    if (failure != null) return CommandResult.failure(failure!);
    return switch (command.method) {
      'coins.account' => const CommandResult.success({'balance_units': 12}),
      'coins.checkin' => const CommandResult.success({
        'reward_coins': 3,
        'account': {'balance_units': 15},
      }),
      'coins.resource' => const CommandResult.success({'balance_units': 10}),
      'coins.resource.status' => const CommandResult.success({'my_coins': 1}),
      _ => CommandResult.failure(CommandError('unexpected', command.method)),
    };
  }

  @override
  Future<void> close() async {}
}
