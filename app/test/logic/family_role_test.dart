import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/family_role.dart';

void main() {
  group('FamilyRole', () {
    test('defines expected enum values and value properties', () {
      expect(FamilyRole.values.length, 2);
      expect(
        FamilyRole.values,
        containsAll([FamilyRole.parent, FamilyRole.nonParent]),
      );
      expect(FamilyRole.parent.value, 'parent');
      expect(FamilyRole.nonParent.value, 'non-parent');
    });

    group('toJson', () {
      test('serializes to expected string representations', () {
        expect(FamilyRole.parent.toJson(), 'parent');
        expect(FamilyRole.nonParent.toJson(), 'non-parent');
      });
    });

    group('fromString', () {
      test('parses valid role strings correctly', () {
        expect(FamilyRole.fromString('parent'), FamilyRole.parent);
        expect(FamilyRole.fromString('non-parent'), FamilyRole.nonParent);
      });

      test(
        'safely defaults to nonParent for null, empty, and unknown values',
        () {
          expect(FamilyRole.fromString(null), FamilyRole.nonParent);
          expect(FamilyRole.fromString(''), FamilyRole.nonParent);
          expect(FamilyRole.fromString('admin'), FamilyRole.nonParent);
          expect(FamilyRole.fromString('child'), FamilyRole.nonParent);
          expect(FamilyRole.fromString('PARENT'), FamilyRole.nonParent);
        },
      );
    });
  });
}
