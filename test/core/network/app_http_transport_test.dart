import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/core/network/github_cdn.dart';
import 'package:oronbox/src/core/network/github_cdn_interceptor.dart';
import 'package:oronbox/src/core/network/http_observability_interceptor.dart';

void main() {
  test('always installs one observability interceptor', () {
    final dio = createAppHttpTransport();

    expect(
      dio.interceptors.whereType<HttpObservabilityInterceptor>(),
      hasLength(1),
    );
    expect(dio.interceptors.whereType<GithubCdnInterceptor>(), isEmpty);
  });

  test('installs the GitHub CDN policy only when requested', () {
    final dio = createAppHttpTransport(githubCdn: () => GitHubCdn.ghfast);

    expect(dio.interceptors.whereType<GithubCdnInterceptor>(), hasLength(1));
    expect(
      dio.interceptors.whereType<HttpObservabilityInterceptor>(),
      hasLength(1),
    );
  });

  test('preserves upstream-specific base options', () {
    final dio = createAppHttpTransport(
      options: BaseOptions(
        baseUrl: 'https://api.example.com',
        connectTimeout: const Duration(seconds: 7),
      ),
    );

    expect(dio.options.baseUrl, 'https://api.example.com');
    expect(dio.options.connectTimeout, const Duration(seconds: 7));
  });
}
