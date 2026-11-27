import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';

void main() {
  CreatorWorkspace workspace({
    String moderationState = 'visible',
    String moderationBy = '',
    List<CreatorRevision> revisions = const [],
    List<Map<String, Object?>> publications = const [],
  }) => CreatorWorkspace(
    resource: CreatorResource(
      id: 'resource',
      slug: 'resource',
      kind: CreatorResourceKind.quickApp,
      moderationState: moderationState,
      moderationBy: moderationBy,
    ),
    revisions: revisions,
    publications: publications,
  );

  const revision = CreatorRevision(
    id: 'rev',
    number: 1,
    name: 'Name',
    summary: '',
    state: 'approved',
  );

  test('moderation states outrank review and publication states', () {
    final published = workspace(
      revisions: const [revision],
      publications: const [
        {'state': 'published'},
      ],
    );
    expect(creatorWorkspaceState(published), 'published');

    final suspended = workspace(
      moderationState: 'suspended',
      revisions: const [revision],
      publications: const [
        {'state': 'published'},
      ],
    );
    expect(creatorWorkspaceState(suspended), 'suspended');

    final frozen = workspace(
      moderationState: 'frozen',
      revisions: const [revision],
      publications: const [
        {'state': 'published'},
      ],
    );
    expect(creatorWorkspaceState(frozen), 'frozen');
  });

  test('restore is only available for owner takedowns', () {
    expect(workspace().resource.canRestore, isFalse);
    expect(
      workspace(
        moderationState: 'suspended',
        moderationBy: 'owner',
      ).resource.canRestore,
      isTrue,
    );
    expect(
      workspace(
        moderationState: 'suspended',
        moderationBy: 'admin',
      ).resource.canRestore,
      isFalse,
    );
    expect(workspace(moderationState: 'frozen').resource.canRestore, isFalse);
  });

  test('resource parses moderation fields from workspace json', () {
    final resource = CreatorResource.fromJson(const {
      'id': 'id',
      'slug': 'slug',
      'kind': 'quickapp',
      'moderation_state': 'suspended',
      'moderation_by': 'admin',
      'moderation_reason': 'policy violation',
    });
    expect(resource.isSuspended, isTrue);
    expect(resource.moderationBy, 'admin');
    expect(resource.moderationReason, 'policy violation');

    final legacy = CreatorResource.fromJson(const {
      'id': 'id',
      'slug': 'slug',
      'kind': 'quickapp',
    });
    expect(legacy.moderationState, 'visible');
  });

  test('revision parses payment metadata with a free legacy default', () {
    final revision = CreatorRevision.fromJson(const {
      'id': 'revision',
      'number': 1,
      'name': 'Resource',
      'summary': '',
      'state': 'draft',
      'paid_type': 'paid',
    });
    expect(revision.paidType, CommunityPaidType.paid);

    final legacy = CreatorRevision.fromJson(const {
      'id': 'legacy',
      'number': 1,
      'name': 'Legacy',
      'summary': '',
      'state': 'draft',
    });
    expect(legacy.paidType, CommunityPaidType.free);
  });

  test('external purchase validation separates drafts from submissions', () {
    expect(
      validateCreatorExternalPurchase(
        enabled: true,
        paidType: CommunityPaidType.paid,
        link: 'https://example.com/full',
        amount: '',
        requireAmount: false,
        requireHttps: true,
      ),
      isNull,
    );
    expect(
      validateCreatorExternalPurchase(
        enabled: true,
        paidType: CommunityPaidType.paid,
        link: 'https://example.com/full',
        amount: '',
        requireAmount: true,
        requireHttps: true,
      ),
      CreatorExternalPurchaseIssue.amount,
    );
  });

  test('BandBBS version fields must be both filled or both empty', () {
    expect(creatorBandBbsVersionFieldsComplete('', ''), isTrue);
    expect(creatorBandBbsVersionFieldsComplete('  ', '\n'), isTrue);
    expect(creatorBandBbsVersionFieldsComplete('版本 2', '修复问题'), isTrue);
    expect(creatorBandBbsVersionFieldsComplete('版本 2', ''), isFalse);
    expect(creatorBandBbsVersionFieldsComplete('', '修复问题'), isFalse);
  });

  test('external purchase validation matches CNY and AstroBox limits', () {
    CreatorExternalPurchaseIssue? validate({
      required String link,
      required String amount,
      bool requireHttps = true,
    }) => validateCreatorExternalPurchase(
      enabled: true,
      paidType: CommunityPaidType.forcePaid,
      link: link,
      amount: amount,
      requireAmount: true,
      requireHttps: requireHttps,
    );

    expect(validate(link: 'https://example.com', amount: '0.01'), isNull);
    expect(
      validate(link: 'https://example.com', amount: '9999999999.99'),
      isNull,
    );
    expect(
      validate(link: 'https://example.com', amount: '0.001'),
      CreatorExternalPurchaseIssue.amount,
    );
    expect(
      validate(link: 'https://example.com', amount: '10000000000.00'),
      CreatorExternalPurchaseIssue.amount,
    );
    expect(
      validate(link: 'http://example.com', amount: '1.00'),
      CreatorExternalPurchaseIssue.link,
    );
    expect(
      validate(link: 'http://example.com', amount: '1.00', requireHttps: false),
      isNull,
    );
    expect(
      validate(link: 'https:///missing-host', amount: '1.00'),
      CreatorExternalPurchaseIssue.link,
    );
    expect(
      validateCreatorExternalPurchase(
        enabled: true,
        paidType: CommunityPaidType.paid,
        link: 'https://example.com/${'a' * 2030}',
        amount: '1.00',
        requireAmount: true,
        requireHttps: true,
      ),
      CreatorExternalPurchaseIssue.link,
    );
  });
}
