import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('FamilyCompletionMode Tests', () {
    test('fromString parses valid values correctly', () {
      expect(
        FamilyCompletionMode.fromString('anyone'),
        FamilyCompletionMode.anyone,
      );
      expect(
        FamilyCompletionMode.fromString('individual'),
        FamilyCompletionMode.individual,
      );
      expect(
        FamilyCompletionMode.fromString('ANYONE'),
        FamilyCompletionMode.anyone,
      );
      expect(
        FamilyCompletionMode.fromString('INDIVIDUAL'),
        FamilyCompletionMode.individual,
      );
    });

    test('fromString defaults to anyone for null and invalid values', () {
      expect(
        FamilyCompletionMode.fromString(null),
        FamilyCompletionMode.anyone,
      );
      expect(FamilyCompletionMode.fromString(''), FamilyCompletionMode.anyone);
      expect(
        FamilyCompletionMode.fromString('unknown_value'),
        FamilyCompletionMode.anyone,
      );
    });

    test('name property returns expected strings', () {
      expect(FamilyCompletionMode.anyone.name, 'anyone');
      expect(FamilyCompletionMode.individual.name, 'individual');
    });
  });
}
