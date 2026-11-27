import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/features/settings/services/oronbox_support_api.dart';

void main() {
  test('authenticated feedback requests run through the host', () async {
    final host = _SupportHost();
    final api = OronBoxSupportApi(Dio(), host);

    final tickets = await api.feedback();
    final detail = await api.feedbackDetail('ticket-1');
    final created = await api.createFeedback(
      kind: 'feedback',
      subject: 'subject',
      message: 'message',
    );
    final replied = await api.replyFeedback('ticket-1', 'reply');

    expect(tickets.single.id, 'ticket-1');
    expect(detail.id, 'ticket-1');
    expect(created.id, 'ticket-1');
    expect(replied.replies.single.message, 'reply');
    expect(
      host.methods,
      equals([
        'support.feedback.list',
        'support.feedback.get',
        'support.feedback.create',
        'support.feedback.reply',
      ]),
    );
  });
}

class _SupportHost implements OronBoxCommandBus {
  final methods = <String>[];

  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    methods.add(command.method);
    final ticket = {
      'id': 'ticket-1',
      'kind': 'feedback',
      'subject': 'subject',
      'message': 'message',
      'status': 'open',
      'created_at': '2026-07-24T00:00:00Z',
      if (command.method == 'support.feedback.reply')
        'replies': [
          {
            'author': 'user',
            'message': command.params['message'],
            'created_at': '2026-07-24T00:00:01Z',
          },
        ],
    };
    return switch (command.method) {
      'support.feedback.list' => CommandResult.success({
        'tickets': [ticket],
      }),
      'support.feedback.get' ||
      'support.feedback.create' ||
      'support.feedback.reply' => CommandResult.success(ticket),
      _ => CommandResult.failure(CommandError('unexpected', command.method)),
    };
  }

  @override
  Future<void> close() async {}
}
