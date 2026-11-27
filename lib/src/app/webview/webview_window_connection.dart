import 'webview_window_connection_stub.dart'
    as platform;

abstract interface class WebViewWindowConnection {
  Future<Object?> invoke(String method, [Object? arguments]);
  Future<void> close();
  Future<void> get disconnected;
}

Future<WebViewWindowConnection> openWebViewWindowConnection(
  Map<String, Object?> options,
  Future<Object?> Function(String method, Object? arguments) handler,
) => platform.openWebViewWindowConnection(options, handler);

Future<WebViewWindowConnection> attachWebViewWindowConnection(
  String id,
  Future<Object?> Function(String method, Object? arguments) handler,
) => platform.attachWebViewWindowConnection(id, handler);
