import 'package:dio/dio.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/network/github_cdn.dart';

/// Rewrites convertible GitHub requests to the configured CDN and, on
/// failure, retries the request through the remaining CDNs in order.
class GithubCdnInterceptor extends Interceptor {
  GithubCdnInterceptor({required this.cdn, this.onFallback});

  static final _log = getLogger('GitHubCdn');

  final GitHubCdn Function() cdn;

  /// Called once per fallback retry so the UI can surface the switch.
  final void Function(GitHubCdn fallback)? onFallback;

  /// Set by the transport so retries share the client configuration.
  Dio? retryDio;

  static const _originalKey = 'githubCdnOriginal';
  static const _retriedKey = 'githubCdnRetried';
  static const _triedKey = 'githubCdnTriedCount';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[_retriedKey] == true) {
      handler.next(options);
      return;
    }
    final rewritten = rewriteGithubCdnUri(options.uri, cdn());
    if (rewritten != options.uri) {
      options.extra[_originalKey] = options.uri.toString();
      options.path = rewritten.toString();
      options.queryParameters.clear();
    } else if (isConvertibleGithubUri(options.uri)) {
      options.extra[_originalKey] = options.uri.toString();
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final original = err.requestOptions.extra[_originalKey]?.toString();
    final originalUri = original == null ? null : Uri.tryParse(original);
    final client = retryDio;
    if (originalUri == null || client == null || !_isRetryable(err)) {
      handler.next(err);
      return;
    }
    final selected = cdn();
    final effective = selected == GitHubCdn.auto ? GitHubCdn.raw : selected;
    final candidates = <GitHubCdn>[
      effective,
      ...GitHubCdn.values.where(
        (value) => value != GitHubCdn.auto && value != effective,
      ),
    ];
    final tried = (err.requestOptions.extra[_triedKey] as int? ?? 0) + 1;
    if (tried >= candidates.length) {
      handler.next(err);
      return;
    }
    final fallback = candidates[tried];
    logDiagnostic(
      _log,
      Level.WARNING,
      'GitHub request failed, retrying via CDN fallback',
      fields: {
        'url': originalUri.toString(),
        'fallback': fallback.name,
        'attempt': tried,
      },
      error: err.message ?? err.type.name,
    );
    onFallback?.call(fallback);
    final options = err.requestOptions
      ..extra[_triedKey] = tried
      ..extra[_retriedKey] = true
      ..path = rewriteGithubCdnUri(originalUri, fallback).toString()
      ..queryParameters.clear();
    try {
      handler.resolve(await client.fetch(options));
    } on DioException catch (retryError) {
      onError(retryError, handler);
    }
  }

  bool _isRetryable(DioException err) {
    if (err.type
        case DioExceptionType.connectionError ||
            DioExceptionType.connectionTimeout ||
            DioExceptionType.sendTimeout ||
            DioExceptionType.receiveTimeout) {
      return true;
    }
    final status = err.response?.statusCode ?? 0;
    return status == 403 || status == 429 || status >= 500;
  }
}
