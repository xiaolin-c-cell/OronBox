import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'mi_account_two_factor_resolver_base.dart';

/// iOS 上的小米账号二次验证解析器。
///
/// iOS 原生侧（Runner/AppDelegate.swift）从未实现 `oronbox/mi_account_2fa`
/// 这个 MethodChannel handler，因此上游的 [NativeMiAccountTwoFactorResolver]
/// 在 iOS 上必然失败。这里改用纯 Dart 的应用内 WebView（flutter_inappwebview）
/// 打开小米的二次验证页，用户在 WebView 内完成短信/扫码验证后，从小米的
/// WKHTTPCookieStore 抓取 session cookie 回传给 Dart 登录流程继续。
///
/// 逻辑与 macOS 版（AppDelegate.swift 的 MacOSMiAccountTwoFactorSession）对齐：
/// 轮询 cookie，一旦抓到 passToken / cUserId / userId 即视为验证完成。
///
/// 注意：WebView 必须放在一个**全屏路由（route）**里，不能嵌进 AlertDialog。
/// 在 iOS 上把 InAppWebView 放进 AlertDialog 时，原生平台视图拿不到合法的
/// UIViewController，会返回 null，从而触发包内 Dart 的 `!` 空断言导致崩溃
/// （"Null check operator used on a null value"）。改用普通路由即可避免。
class InAppWebViewMiAccountTwoFactorResolver implements MiAccountTwoFactorResolver {
  const InAppWebViewMiAccountTwoFactorResolver();

  @override
  Future<String> resolve(BuildContext context, Uri notificationUrl) async {
    final completer = Completer<String>();
    InAppWebViewController? controller;
    Timer? pollTimer;
    Timer? timeoutTimer;
    var settled = false;

    void finish({
      String? cookieHeader,
      String? errorMessage,
    }) {
      if (settled) {
        return;
      }
      settled = true;
      pollTimer?.cancel();
      pollTimer = null;
      timeoutTimer?.cancel();
      timeoutTimer = null;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop();
      }
      if (cookieHeader != null && cookieHeader.isNotEmpty) {
        completer.complete(cookieHeader);
      } else {
        completer.completeError(
          StateError(errorMessage ?? '小米账号二次验证未完成或已取消'),
        );
      }
    }

    void checkCookies() {
      if (controller == null || settled) {
        return;
      }
      CookieManager.instance().getAllCookies().then((cookies) {
        final list = cookies ?? const <Cookie>[];
        final header = _cookieHeader(list);
        if (_hasSessionCookie(header)) {
          finish(cookieHeader: header);
        }
      }).catchError((Object _) {
        // 单次轮询失败不致命，下一轮继续。
      });
    }

    final route = MaterialPageRoute<void>(
      builder: (routeContext) => Scaffold(
        appBar: AppBar(
          title: const Text('小米账号验证'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () =>
                finish(errorMessage: '用户取消了小米账号二次验证'),
          ),
        ),
        body: SafeArea(
          child: InAppWebView(
            initialSettings: InAppWebViewSettings(),
            initialUrlRequest: URLRequest(
              url: WebUri(notificationUrl.toString()),
            ),
            onWebViewCreated: (created) {
              controller = created;
              pollTimer ??= Timer.periodic(
                const Duration(milliseconds: 750),
                (_) => checkCookies(),
              );
            },
            onLoadStop: (c, url) => checkCookies(),
          ),
        ),
      ),
    );

    // 兜底超时：万一页面没回调（例如验证完成但 cookie 未写入），4 分钟后主动结束，
    // 避免界面卡死。
    timeoutTimer = Timer(const Duration(minutes: 4), () {
      if (!settled) {
        finish(errorMessage: '小米账号验证超时，请重试或检查网络');
      }
    });

    try {
      await Navigator.of(context, rootNavigator: true).push(route);
    } catch (error, stack) {
      if (!settled) {
        settled = true;
        pollTimer?.cancel();
        timeoutTimer?.cancel();
        completer.completeError(
          StateError('小米账号验证页面打开失败：$error\n$stack'),
        );
      }
      return completer.future;
    }

    // 路由被关闭（用户返回 / 关闭按钮）且尚未完成时，视为取消。
    if (!settled) {
      finish(errorMessage: '用户取消了小米账号二次验证');
    }
    return completer.future;
  }

  String _cookieHeader(List<Cookie> cookies) {
    final values = <String, String>{};
    for (final cookie in cookies) {
      if (cookie.name.isEmpty || cookie.value.isEmpty) {
        continue;
      }
      values[cookie.name] = cookie.value;
    }
    return values.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  bool _hasSessionCookie(String header) {
    final names = header
        .split(';')
        .map((part) {
          final index = part.indexOf('=');
          return (index < 0 ? part : part.substring(0, index)).trim();
        })
        .toSet();
    return names.contains('passToken') ||
        names.contains('cUserId') ||
        names.contains('userId');
  }
}
