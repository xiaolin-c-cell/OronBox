import 'package:flutter/services.dart';

/// iOS Live Activity POC 桥接。
/// 仅用于验证无签名 ad-hoc 包能否装载 Widget Extension 并显示灵动岛卡片。
/// POC 通过后正式接入时应替换为队列进度等真实数据模型。
class LiveActivityPocBridge {
  static const _channel = MethodChannel('oronbox/live_activity');

  static Future<bool> enabled() async {
    try {
      return await _channel.invokeMethod<bool>('enabled') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<String?> startTest({
    String title = 'OronBox POC',
    String detail = '灵动岛 POC 测试卡片',
    double progress = 0.35,
  }) async {
    try {
      return await _channel.invokeMethod<String>('startTest', {
        'title': title,
        'detail': detail,
        'progress': progress,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> updateTest(
    String id, {
    String title = 'OronBox POC',
    String detail = '已更新',
    double progress = 0.75,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateTest', {
        'id': id,
        'title': title,
        'detail': detail,
        'progress': progress,
      });
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }

  static Future<void> endTest([String? id]) async {
    try {
      await _channel.invokeMethod<void>('endTest', id);
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }
}
