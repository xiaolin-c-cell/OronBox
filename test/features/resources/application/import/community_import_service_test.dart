import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/features/resources/application/import/community_import_service.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/community_resource_codec.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';

CommunityResourceDetail _detail(
  String id,
  String name, {
  CommunitySourceId source = CommunitySourceId.bandbbs,
  CommunityResourceType type = CommunityResourceType.watchface,
  String content = '',
  ResourceContentFormat format = ResourceContentFormat.plainText,
  Uri? iconUrl,
  Uri? coverUrl,
  Uri? publicUrl,
  String? sourceRepoOwner,
  String? sourceRepoName,
  String? sourceRepoCommitHash,
  List<String> tags = const [],
}) => CommunityResourceDetail(
  ref: ResourceRef(source: source, id: id),
  name: name,
  type: type,
  paidType: CommunityPaidType.free,
  authors: const [],
  supportedDevices: const {},
  content: CommunityResourceContent(format: format, value: content),
  files: const [],
  iconUrl: iconUrl,
  coverUrl: coverUrl,
  publicUrl: publicUrl,
  sourceRepoOwner: sourceRepoOwner,
  sourceRepoName: sourceRepoName,
  sourceRepoCommitHash: sourceRepoCommitHash,
  tags: tags,
);

void main() {
  test('title normalization trims, lowercases, and collapses whitespace', () {
    expect(normalizeCommunityImportTitle('  EdgeUI  照片表盘 \n'), 'edgeui 照片表盘');
  });

  test('slug follows the server pattern with fallbacks', () {
    expect(communityImportSlug('EdgeUI Photo 2'), 'edgeui-photo-2');
    expect(communityImportSlug('表盘'), 'import');
    expect(communityImportSlug('--weird--'), 'weird');
    expect(communityImportSlug('--'), 'import');
    expect(communityImportSlug('ab'), 'ab');
    expect(communityImportSlug('a' * 80).length, lessThanOrEqualTo(64));
    for (final slug in [
      communityImportSlug('EdgeUI Photo 2'),
      communityImportSlug('表盘'),
      communityImportSlug('a.b_c-d'),
    ]) {
      expect(RegExp(r'^[a-z0-9][a-z0-9._-]{1,63}$').hasMatch(slug), isTrue);
    }
  });

  test('import order puts AstroBox first, richest first within a source', () {
    final ordered = communityImportOrder([
      _detail('1', 'b', iconUrl: Uri.parse('https://example.com/icon.png')),
      _detail('2', 'a', source: CommunitySourceId.astroboxRepo),
      _detail('3', 'c'),
      _detail(
        '4',
        'd',
        source: CommunitySourceId.astroboxRepo,
        iconUrl: Uri.parse('https://example.com/icon.png'),
        coverUrl: Uri.parse('https://example.com/cover.png'),
      ),
    ]);

    expect(ordered.map((detail) => detail.ref.id), ['4', '2', '1', '3']);
  });

  test('html descriptions convert to plain markdown-ish text', () {
    final detail = _detail(
      '1',
      'x',
      format: ResourceContentFormat.html,
      content:
          '<p>Hello &amp; welcome</p><br><a href="https://a.b">link</a><b>bold</b>',
    );
    expect(
      communityImportSummaryText(detail),
      'Hello & welcome\n\n[link](https://a.b)bold',
    );
  });

  test('AstroBox identity survives catalog transport', () {
    final original = _detail(
      'neo-music',
      'NeoMusic',
      source: CommunitySourceId.astroboxRepo,
      publicUrl: Uri.parse('https://github.com/owner/neo-music'),
      sourceRepoOwner: 'owner',
      sourceRepoName: 'neo-music',
      sourceRepoCommitHash: '0123456789abcdef',
      tags: const ['Music', 'VelaOS'],
    );

    final restored = communityResourceDetailFromJson(
      communityResourceDetailToJson(original),
    );

    expect(restored.publicUrl, original.publicUrl);
    expect(restored.sourceRepoOwner, 'owner');
    expect(restored.sourceRepoName, 'neo-music');
    expect(restored.sourceRepoCommitHash, '0123456789abcdef');
    expect(restored.tags, ['Music', 'VelaOS']);
  });

  test('bundle manifest matches the creator draft schema', () {
    final bundle = buildCommunityImportBundle(
      kind: CreatorResourceKind.watchface,
      name: 'EdgeUI',
      summary: 'summary',
      paidType: CommunityPaidType.paid,
      purchaseLink: Uri.parse('https://example.com/full'),
      links: const [
        {'title': '米坛社区', 'url': 'https://www.bandbbs.cn/resources/1/'},
      ],
      icon: CommunityImportMedia(
        extension: 'webp',
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 256,
        height: 256,
      ),
      previews: [
        CommunityImportMedia(
          extension: 'webp',
          bytes: Uint8List.fromList([4, 5]),
          width: 100,
          height: 50,
        ),
      ],
      artifacts: [
        CommunityImportArtifact(
          name: 'face.bin',
          payload: Uint8List.fromList([9, 9, 9]),
          type: 'velaos_watchface',
          packageId: 'com.example.face',
          version: '1.0',
          deviceIds: {'dev-1'},
        ),
      ],
      bindings: const [
        CommunityImportBinding(
          provider: 'astrobox',
          externalId: 'edgeui-face',
          externalUrl: 'https://github.com/example/edgeui-face',
        ),
        CommunityImportBinding(
          provider: 'bandbbs',
          externalId: '{"12":"345"}',
          externalUrl: 'https://www.bandbbs.cn/resources/345/',
        ),
      ],
    );

    final archive = ZipDecoder().decodeBytes(bundle);
    final manifest =
        jsonDecode(
              utf8.decode(
                archive.files
                        .firstWhere((file) => file.name == 'manifest.json')
                        .content
                    as List<int>,
              ),
            )
            as Map<String, Object?>;
    expect(manifest['version'], 1);
    expect(manifest['kind'], 'watchface');
    expect(manifest['name'], 'EdgeUI');
    expect(manifest['paid_type'], 'paid');
    expect(manifest['purchase_link'], 'https://example.com/full');
    expect(manifest.containsKey('purchase_price'), isFalse);
    expect(manifest['purchase_currency'], 'CNY');
    expect(manifest['attributes'], isEmpty);
    // No publications key: the server stores a null plan so the editor derives
    // publish targets from the imported bindings.
    expect(manifest.containsKey('publications'), isFalse);
    final media = manifest['media'] as Map<String, Object?>;
    expect((media['icon'] as Map)['file'], 'media/icon.webp');
    expect((media['icon'] as Map)['width'], 256);
    expect((media['previews'] as List), hasLength(1));
    final artifacts = manifest['artifacts'] as List;
    expect(artifacts, hasLength(1));
    final artifact = artifacts.single as Map;
    expect(artifact['file'], 'artifacts/0.bin');
    expect(artifact['type'], 'velaos_watchface');
    expect(artifact['device_ids'], ['dev-1']);
    expect(
      archive.files.map((file) => file.name),
      containsAll([
        'media/icon.webp',
        'media/preview-0.webp',
        'artifacts/0.bin',
      ]),
    );
    final bindings = manifest['bindings'] as List;
    expect(bindings, hasLength(2));
    expect((bindings.first as Map)['provider'], 'astrobox');
    expect((bindings.last as Map)['external_id'], '{"12":"345"}');
  });

  test('import binding validation rejects silently dropped metadata', () {
    const expected = [
      CommunityImportBinding(
        provider: 'astrobox',
        externalId: 'neo-music',
        externalUrl: 'https://github.com/owner/neo-music',
        meta: {'repo_owner': 'owner', 'repo_name': 'neo-music'},
      ),
    ];

    expect(
      () => validateCommunityImportBindings(expected, const [
        {
          'provider': 'astrobox',
          'external_id': 'neo-music',
          'meta': {'repo_owner': 'owner'},
        },
      ]),
      throwsStateError,
    );
    expect(
      () => validateCommunityImportBindings(expected, const [
        {
          'provider': 'astrobox',
          'external_id': 'neo-music',
          'meta': {'repo_owner': 'owner', 'repo_name': 'neo-music'},
        },
      ]),
      returnsNormally,
    );
  });
}
