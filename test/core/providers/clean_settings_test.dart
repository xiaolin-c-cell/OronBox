import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';

void main() {
  test(
    'explore parent disables every explore feature without losing choices',
    () {
      const clean = CleanSettings(
        exploreEntry: false,
        homeFeed: true,
        explore: true,
        creator: true,
        inbox: true,
        comments: true,
        oronBox: true,
      );

      expect(clean.exploreEnabled, isFalse);
      expect(clean.homeFeedEnabled, isFalse);
      expect(clean.creatorEnabled, isFalse);
      expect(clean.inboxEnabled, isFalse);
      expect(clean.commentsEnabled, isFalse);
      expect(clean.oronBoxSourceEnabled, isFalse);
      expect(clean.homeFeed, isTrue);
      expect(clean.explore, isTrue);
    },
  );

  test('resource features depend on both explore and resource library', () {
    const clean = CleanSettings(
      exploreEntry: true,
      explore: false,
      comments: true,
      bandBbs: true,
    );

    expect(clean.exploreEnabled, isTrue);
    expect(clean.commentsEnabled, isFalse);
    expect(clean.bandBbsSourceEnabled, isFalse);
  });

  test('GitHub login follows the BandBBS login capability', () {
    const clean = CleanSettings(bandBbsLogin: false, githubLogin: true);

    expect(clean.bandBbsLoginEnabled, isFalse);
    expect(clean.githubLoginEnabled, isFalse);
    expect(clean.githubLogin, isTrue);
  });

  test('all resource sources may be disabled', () {
    const clean = CleanSettings(
      oronBox: false,
      bandBbs: false,
      astroBox: false,
      huamiAppStore: false,
    );

    expect(clean.normalized.oronBox, isFalse);
    expect(clean.normalized.bandBbs, isFalse);
    expect(clean.normalized.astroBox, isFalse);
    expect(clean.normalized.huamiAppStore, isFalse);
    expect(clean.normalized.hasResourceSource, isFalse);
  });

  test('plugins and Amazfit App Store are enabled by default', () {
    const clean = CleanSettings();

    expect(clean.pluginsEnabled, isTrue);
    expect(clean.huamiAppStoreSourceEnabled, isTrue);
  });
}
