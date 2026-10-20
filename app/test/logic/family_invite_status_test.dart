import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/family_invite_status.dart';

void main() {
  group('FamilyInviteStatus', () {
    test('defines expected enum values', () {
      expect(FamilyInviteStatus.values.length, 3);
      expect(
        FamilyInviteStatus.values,
        containsAll([
          FamilyInviteStatus.pending,
          FamilyInviteStatus.accepted,
          FamilyInviteStatus.declined,
        ]),
      );
      expect(FamilyInviteStatus.pending.name, 'pending');
      expect(FamilyInviteStatus.accepted.name, 'accepted');
      expect(FamilyInviteStatus.declined.name, 'declined');
    });

    group('toJson', () {
      test('serializes to expected string representations', () {
        expect(FamilyInviteStatus.pending.toJson(), 'pending');
        expect(FamilyInviteStatus.accepted.toJson(), 'accepted');
        expect(FamilyInviteStatus.declined.toJson(), 'declined');
      });
    });

    group('fromString', () {
      test('parses standard lowercase strings correctly', () {
        expect(
          FamilyInviteStatus.fromString('pending'),
          FamilyInviteStatus.pending,
        );
        expect(
          FamilyInviteStatus.fromString('accepted'),
          FamilyInviteStatus.accepted,
        );
        expect(
          FamilyInviteStatus.fromString('declined'),
          FamilyInviteStatus.declined,
        );
      });

      test('parses case-insensitive inputs correctly', () {
        expect(
          FamilyInviteStatus.fromString('ACCEPTED'),
          FamilyInviteStatus.accepted,
        );
        expect(
          FamilyInviteStatus.fromString('Accepted'),
          FamilyInviteStatus.accepted,
        );
        expect(
          FamilyInviteStatus.fromString('DECLINED'),
          FamilyInviteStatus.declined,
        );
        expect(
          FamilyInviteStatus.fromString('Declined'),
          FamilyInviteStatus.declined,
        );
        expect(
          FamilyInviteStatus.fromString('PENDING'),
          FamilyInviteStatus.pending,
        );
        expect(
          FamilyInviteStatus.fromString('Pending'),
          FamilyInviteStatus.pending,
        );
      });

      test(
        'safely defaults to pending for null, empty, and unknown values',
        () {
          expect(
            FamilyInviteStatus.fromString(null),
            FamilyInviteStatus.pending,
          );
          expect(FamilyInviteStatus.fromString(''), FamilyInviteStatus.pending);
          expect(
            FamilyInviteStatus.fromString('unknown'),
            FamilyInviteStatus.pending,
          );
          expect(
            FamilyInviteStatus.fromString('rejected'),
            FamilyInviteStatus.pending,
          );
          expect(
            FamilyInviteStatus.fromString('expired'),
            FamilyInviteStatus.pending,
          );
        },
      );
    });
  });
}
