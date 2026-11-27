import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/network/dio_provider.dart';
import 'package:oronbox/src/data/oronbox/oronbox_home_api.dart';
import 'package:oronbox/src/features/resources/controllers/resource_filter_controller.dart';

final oronBoxHomeApiProvider = Provider<OronBoxHomeApi>(
  (ref) => OronBoxHomeApi(dio: ref.watch(appDioProvider)),
);

final homeFeedProvider = FutureProvider.autoDispose<HomeFeed>((ref) {
  ref.watch(resourceRefreshProvider);
  return ref.watch(oronBoxHomeApiProvider).fetchHome();
});

final blogPostProvider = FutureProvider.autoDispose.family<BlogPost, String>(
  (ref, slug) => ref.watch(oronBoxHomeApiProvider).fetchBlogPost(slug),
);
