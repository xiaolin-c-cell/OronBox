import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/features/resources/pages/resources_page.dart';

void main() {
  group('enabledCommunitySources', () {
    test('shows every device-agnostic source with defaults when no ZeppOS device', () {
      const clean = CleanSettings();
      expect(
        enabledCommunitySources(null, clean, isZepposDevice: false),
        [
          CommunitySourceId.oronBox,
          CommunitySourceId.astroboxRepo,
          CommunitySourceId.bandbbs,
        ],
      );
    });

    test('hides OronBox and AstroBox but shows Huami store on a ZeppOS device', () {
      const clean = CleanSettings();
      expect(
        enabledCommunitySources(null, clean, isZepposDevice: true),
        [
          CommunitySourceId.bandbbs,
          CommunitySourceId.huamiAppStore,
        ],
      );
    });

    test('Huami store toggle still gates the source on a ZeppOS device', () {
      const clean = CleanSettings(huamiAppStore: false);
      expect(
        enabledCommunitySources(null, clean, isZepposDevice: true),
        [CommunitySourceId.bandbbs],
      );
    });

    test('OronBox toggle cannot bring the source back on a ZeppOS device', () {
      const clean = CleanSettings(oronBox: false);
      expect(
        enabledCommunitySources(null, clean, isZepposDevice: true),
        [
          CommunitySourceId.bandbbs,
          CommunitySourceId.huamiAppStore,
        ],
      );
    });

    test('AstroBox toggle cannot bring the source back on a ZeppOS device', () {
      const clean = CleanSettings(astroBox: false);
      expect(
        enabledCommunitySources(null, clean, isZepposDevice: true),
        [
          CommunitySourceId.bandbbs,
          CommunitySourceId.huamiAppStore,
        ],
      );
    });

    test('BandBBS toggle hides the source on either device kind', () {
      const clean = CleanSettings(bandBbs: false);
      expect(
        enabledCommunitySources(null, clean, isZepposDevice: false),
        [CommunitySourceId.oronBox, CommunitySourceId.astroboxRepo],
      );
      expect(
        enabledCommunitySources(null, clean, isZepposDevice: true),
        [CommunitySourceId.huamiAppStore],
      );
    });

    test('source toggles apply without a ZeppOS device', () {
      const clean = CleanSettings(oronBox: false, astroBox: false);
      expect(
        enabledCommunitySources(null, clean, isZepposDevice: false),
        [CommunitySourceId.bandbbs],
      );
    });

    test('honours the host-provided source list instead of defaults', () {
      const clean = CleanSettings();
      final loaded = [
        CommunitySourceId.oronBox,
        CommunitySourceId.bandbbs,
        CommunitySourceId.plugin('demo'),
      ];
      expect(
        enabledCommunitySources(loaded, clean, isZepposDevice: false),
        [
          CommunitySourceId.oronBox,
          CommunitySourceId.bandbbs,
          CommunitySourceId.plugin('demo'),
        ],
      );
      expect(
        enabledCommunitySources(loaded, clean, isZepposDevice: true),
        [CommunitySourceId.bandbbs, CommunitySourceId.plugin('demo')],
      );
    });
  });
}
