import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/family.dart';

void main() {
  group('FamilyMember', () {
    group('lastSeenAt parsing variations', () {
      test('parses Timestamp correctly', () {
        final now = DateTime.utc(2026, 9, 29, 12, 0, 0);
        final timestamp = Timestamp.fromDate(now);
        final member = FamilyMember.fromJson({
          'userId': 'u1',
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'role': 'parent',
          'lastSeenAt': timestamp,
        });

        expect(member.lastSeenAt, equals(timestamp.toDate()));
        expect(member.lastSeenAt?.isAtSameMomentAs(now), isTrue);
      });

      test('parses ISO 8601 String correctly', () {
        const isoString = '2026-09-29T12:00:00.000Z';
        final expectedDate = DateTime.parse(isoString);
        final member = FamilyMember.fromJson({
          'userId': 'u1',
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'role': 'parent',
          'lastSeenAt': isoString,
        });

        expect(member.lastSeenAt, equals(expectedDate));
      });

      test('parses integer epoch milliseconds correctly', () {
        final now = DateTime.utc(2026, 9, 29, 12, 0, 0);
        final millis = now.millisecondsSinceEpoch;
        final member = FamilyMember.fromJson({
          'userId': 'u1',
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'role': 'parent',
          'lastSeenAt': millis,
        });

        expect(
          member.lastSeenAt,
          equals(DateTime.fromMillisecondsSinceEpoch(millis)),
        );
      });

      test('handles null and omitted lastSeenAt gracefully', () {
        final memberExplicitNull = FamilyMember.fromJson({
          'userId': 'u1',
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'role': 'parent',
          'lastSeenAt': null,
        });
        expect(memberExplicitNull.lastSeenAt, isNull);

        final memberOmitted = FamilyMember.fromJson({
          'userId': 'u1',
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'role': 'parent',
        });
        expect(memberOmitted.lastSeenAt, isNull);
      });

      test('handles invalid string or unsupported types without throwing', () {
        final memberInvalidString = FamilyMember.fromJson({
          'userId': 'u1',
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'role': 'parent',
          'lastSeenAt': 'invalid-date-string',
        });
        expect(memberInvalidString.lastSeenAt, isNull);

        final memberUnsupportedType = FamilyMember.fromJson({
          'userId': 'u1',
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'role': 'parent',
          'lastSeenAt': true,
        });
        expect(memberUnsupportedType.lastSeenAt, isNull);
      });
    });

    group('role fallback and deserialization', () {
      test('deserializes standard roles correctly', () {
        final parentMember = FamilyMember.fromJson({
          'userId': 'u1',
          'role': 'parent',
        });
        expect(parentMember.role, equals(FamilyRole.parent));

        final nonParentMember = FamilyMember.fromJson({
          'userId': 'u2',
          'role': 'non-parent',
        });
        expect(nonParentMember.role, equals(FamilyRole.nonParent));
      });

      test('falls back to nonParent when role is null or omitted', () {
        final nullRoleMember = FamilyMember.fromJson({
          'userId': 'u1',
          'role': null,
        });
        expect(nullRoleMember.role, equals(FamilyRole.nonParent));

        final omittedRoleMember = FamilyMember.fromJson({'userId': 'u1'});
        expect(omittedRoleMember.role, equals(FamilyRole.nonParent));
      });

      test('falls back to nonParent when role is unknown string', () {
        final unknownRoleMember = FamilyMember.fromJson({
          'userId': 'u1',
          'role': 'administrator',
        });
        expect(unknownRoleMember.role, equals(FamilyRole.nonParent));
      });
    });

    group('field defaults and optional fields', () {
      test('defaults required string fields to empty strings when missing', () {
        final member = FamilyMember.fromJson({});
        expect(member.userId, equals(''));
        expect(member.displayName, equals(''));
        expect(member.email, equals(''));
        expect(member.appVersion, isNull);
        expect(member.platform, isNull);
      });

      test('parses optional fields when present', () {
        final member = FamilyMember.fromJson({
          'userId': 'u1',
          'displayName': 'Bob',
          'email': 'bob@example.com',
          'appVersion': '1.2.3',
          'platform': 'android',
        });
        expect(member.appVersion, equals('1.2.3'));
        expect(member.platform, equals('android'));
      });
    });

    group('immutability and copyWith', () {
      test('updates specified fields while preserving untouched fields', () {
        final original = FamilyMember(
          userId: 'u1',
          displayName: 'Alice',
          email: 'alice@example.com',
          role: FamilyRole.nonParent,
          appVersion: '1.0.0',
          platform: 'ios',
          lastSeenAt: DateTime.utc(2026, 1, 1),
        );

        final updated = original.copyWith(
          displayName: 'Alice Cooper',
          role: FamilyRole.parent,
          lastSeenAt: DateTime.utc(2026, 9, 29),
        );

        expect(updated.userId, equals('u1'));
        expect(updated.displayName, equals('Alice Cooper'));
        expect(updated.email, equals('alice@example.com'));
        expect(updated.role, equals(FamilyRole.parent));
        expect(updated.appVersion, equals('1.0.0'));
        expect(updated.platform, equals('ios'));
        expect(updated.lastSeenAt, equals(DateTime.utc(2026, 9, 29)));
      });

      test('retains all original values when no parameters are provided', () {
        final original = FamilyMember(
          userId: 'u1',
          displayName: 'Alice',
          email: 'alice@example.com',
          role: FamilyRole.parent,
          appVersion: '1.0.0',
          platform: 'ios',
          lastSeenAt: DateTime.utc(2026, 1, 1),
        );

        final copied = original.copyWith();

        expect(copied.userId, equals(original.userId));
        expect(copied.displayName, equals(original.displayName));
        expect(copied.email, equals(original.email));
        expect(copied.role, equals(original.role));
        expect(copied.appVersion, equals(original.appVersion));
        expect(copied.platform, equals(original.platform));
        expect(copied.lastSeenAt, equals(original.lastSeenAt));
      });
    });

    group('serialization (toJson)', () {
      test('serializes all fields correctly when populated', () {
        final date = DateTime.utc(2026, 9, 29, 8, 30, 0);
        final member = FamilyMember(
          userId: 'u1',
          displayName: 'Alice',
          email: 'alice@example.com',
          role: FamilyRole.parent,
          appVersion: '2.0.0',
          platform: 'web',
          lastSeenAt: date,
        );

        final json = member.toJson();
        expect(json, {
          'userId': 'u1',
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'role': 'parent',
          'appVersion': '2.0.0',
          'platform': 'web',
          'lastSeenAt': '2026-09-29T08:30:00.000Z',
        });
      });

      test('omits optional fields when null', () {
        const member = FamilyMember(
          userId: 'u2',
          displayName: 'Bob',
          email: 'bob@example.com',
          role: FamilyRole.nonParent,
        );

        final json = member.toJson();
        expect(json, {
          'userId': 'u2',
          'displayName': 'Bob',
          'email': 'bob@example.com',
          'role': 'non-parent',
        });
        expect(json.containsKey('appVersion'), isFalse);
        expect(json.containsKey('platform'), isFalse);
        expect(json.containsKey('lastSeenAt'), isFalse);
      });
    });
  });

  group('FamilyInvite', () {
    group('timestamp handling (createdAt)', () {
      test('parses Timestamp correctly', () {
        final timestamp = Timestamp.fromDate(DateTime.utc(2026, 5, 1, 10, 0));
        final invite = FamilyInvite.fromJson({
          'createdAt': timestamp,
        }, 'inv123');

        expect(invite.createdAt, equals(timestamp.toDate()));
      });

      test('falls back to current time when createdAt is null or omitted', () {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        final inviteNull = FamilyInvite.fromJson({'createdAt': null}, 'inv1');
        final after = DateTime.now().add(const Duration(seconds: 1));

        expect(inviteNull.createdAt.isAfter(before), isTrue);
        expect(inviteNull.createdAt.isBefore(after), isTrue);

        final inviteOmitted = FamilyInvite.fromJson({}, 'inv2');
        expect(inviteOmitted.createdAt.isAfter(before), isTrue);
        expect(inviteOmitted.createdAt.isBefore(after), isTrue);
      });
    });

    group('role & status fallbacks', () {
      test('falls back to nonParent when role is missing or invalid', () {
        final inviteMissing = FamilyInvite.fromJson({}, 'inv1');
        expect(inviteMissing.role, equals(FamilyRole.nonParent));

        final inviteInvalid = FamilyInvite.fromJson({
          'role': 'invalid',
        }, 'inv2');
        expect(inviteInvalid.role, equals(FamilyRole.nonParent));
      });

      test('falls back to pending when status is missing or invalid', () {
        final inviteMissing = FamilyInvite.fromJson({}, 'inv1');
        expect(inviteMissing.status, equals(FamilyInviteStatus.pending));

        final inviteInvalid = FamilyInvite.fromJson({
          'status': 'invalid',
        }, 'inv2');
        expect(inviteInvalid.status, equals(FamilyInviteStatus.pending));
      });

      test('parses valid statuses correctly', () {
        for (final status in [
          ('pending', FamilyInviteStatus.pending),
          ('accepted', FamilyInviteStatus.accepted),
          ('declined', FamilyInviteStatus.declined),
        ]) {
          final invite = FamilyInvite.fromJson({'status': status.$1}, 'inv');
          expect(invite.status, equals(status.$2));
        }
      });

      test('parses valid role correctly', () {
        final invite = FamilyInvite.fromJson({'role': 'parent'}, 'inv');
        expect(invite.role, equals(FamilyRole.parent));
      });
    });

    group('document ID & field deserialization', () {
      test(
        'populates id from documentId and defaults string fields to empty string',
        () {
          final invite = FamilyInvite.fromJson({}, 'doc-id-456');

          expect(invite.id, equals('doc-id-456'));
          expect(invite.familyId, equals(''));
          expect(invite.familyName, equals(''));
          expect(invite.fromEmail, equals(''));
          expect(invite.fromName, equals(''));
          expect(invite.toEmail, equals(''));
        },
      );

      test('populates all provided string fields', () {
        final invite = FamilyInvite.fromJson({
          'familyId': 'fam-1',
          'familyName': 'The Smiths',
          'fromEmail': 'parent@example.com',
          'fromName': 'Parent Smith',
          'toEmail': 'child@example.com',
          'role': 'non-parent',
          'status': 'pending',
        }, 'doc-id-789');

        expect(invite.id, equals('doc-id-789'));
        expect(invite.familyId, equals('fam-1'));
        expect(invite.familyName, equals('The Smiths'));
        expect(invite.fromEmail, equals('parent@example.com'));
        expect(invite.fromName, equals('Parent Smith'));
        expect(invite.toEmail, equals('child@example.com'));
        expect(invite.role, equals(FamilyRole.nonParent));
        expect(invite.status, equals(FamilyInviteStatus.pending));
      });
    });

    group('serialization (toJson)', () {
      test('serializes all fields and converts createdAt to Timestamp', () {
        final createdAt = DateTime.utc(2026, 9, 29, 10, 0, 0);
        final invite = FamilyInvite(
          id: 'inv-doc-id',
          familyId: 'fam-123',
          familyName: 'Smith Family',
          fromEmail: 'inviter@test.com',
          fromName: 'Inviter Name',
          toEmail: 'invitee@test.com',
          role: FamilyRole.parent,
          status: FamilyInviteStatus.accepted,
          createdAt: createdAt,
        );

        final json = invite.toJson();

        expect(json['familyId'], equals('fam-123'));
        expect(json['familyName'], equals('Smith Family'));
        expect(json['fromEmail'], equals('inviter@test.com'));
        expect(json['fromName'], equals('Inviter Name'));
        expect(json['toEmail'], equals('invitee@test.com'));
        expect(json['role'], equals('parent'));
        expect(json['status'], equals('accepted'));
        expect(json['createdAt'], equals(Timestamp.fromDate(createdAt)));
        expect(
          (json['createdAt'] as Timestamp).toDate().isAtSameMomentAs(createdAt),
          isTrue,
        );
        expect(json.containsKey('id'), isFalse);
      });

      test('round-trip serialization integrity', () {
        final createdAt = DateTime.utc(2026, 9, 29, 10, 0, 0);
        final original = FamilyInvite(
          id: 'round-trip-id',
          familyId: 'fam-abc',
          familyName: 'Johnson Family',
          fromEmail: 'john@example.com',
          fromName: 'John',
          toEmail: 'sarah@example.com',
          role: FamilyRole.nonParent,
          status: FamilyInviteStatus.declined,
          createdAt: createdAt,
        );

        final json = original.toJson();
        final reconstructed = FamilyInvite.fromJson(json, original.id);

        expect(reconstructed.id, equals(original.id));
        expect(reconstructed.familyId, equals(original.familyId));
        expect(reconstructed.familyName, equals(original.familyName));
        expect(reconstructed.fromEmail, equals(original.fromEmail));
        expect(reconstructed.fromName, equals(original.fromName));
        expect(reconstructed.toEmail, equals(original.toEmail));
        expect(reconstructed.role, equals(original.role));
        expect(reconstructed.status, equals(original.status));
        expect(
          reconstructed.createdAt.isAtSameMomentAs(original.createdAt),
          isTrue,
        );
      });
    });
  });
}
