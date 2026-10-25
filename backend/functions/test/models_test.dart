import 'package:functions/src/models/account_deletion.dart';
import 'package:functions/src/models/task_event.dart';
import 'package:test/test.dart';

void main() {
  group('AccountDeletion models', () {
    test('AuthenticatedUser toJson and equality', () {
      const userWithEmail = AuthenticatedUser(
        uid: 'u-1',
        email: 'user@example.com',
      );
      const userWithoutEmail = AuthenticatedUser(uid: 'u-1');

      expect(
        userWithEmail.toJson(),
        equals({'uid': 'u-1', 'email': 'user@example.com'}),
      );
      expect(userWithoutEmail.toJson(), equals({'uid': 'u-1'}));
      expect(
        userWithEmail,
        equals(const AuthenticatedUser(uid: 'u-1', email: 'user@example.com')),
      );
      expect(userWithEmail.hashCode, isNot(equals(userWithoutEmail.hashCode)));
      expect(userWithEmail, isNot(equals(userWithoutEmail)));
    });

    test('AccountDeletionResult round-trip JSON and defaults', () {
      const result = AccountDeletionResult(
        success: true,
        message: 'Account deleted',
        userId: 'u-123',
      );
      final json = result.toJson();
      final restored = AccountDeletionResult.fromJson(json);

      expect(restored, equals(result));
      expect(restored.hashCode, equals(result.hashCode));

      final empty = AccountDeletionResult.fromJson(const {});
      expect(empty.success, isFalse);
      expect(empty.message, isEmpty);
      expect(empty.userId, isEmpty);
    });
  });

  group('TaskEvent models', () {
    test('ExternalTaskEvent round-trip JSON and equality', () {
      const event = ExternalTaskEvent(
        userId: 'u-1',
        providerId: 'meal-planner',
        entityType: 'meal',
        externalId: 'ext-42',
        date: '2026-09-16',
        action: 'completed',
        timestamp: '2026-09-16T12:00:00Z',
        metadata: {'calories': 600},
      );

      final json = event.toJson();
      final restored = ExternalTaskEvent.fromJson(json);
      expect(restored, equals(event));
      expect(restored.hashCode, equals(event.hashCode));
      expect(restored.metadata, equals({'calories': 600}));

      const minimal = ExternalTaskEvent(
        userId: 'u-1',
        providerId: 'meal-planner',
        entityType: 'meal',
        externalId: 'ext-42',
        date: '2026-09-16',
        action: 'completed',
      );
      expect(minimal.toJson().containsKey('timestamp'), isFalse);
      expect(minimal.toJson().containsKey('metadata'), isFalse);
    });

    test('TaskEventResult round-trip JSON and optional fields', () {
      const result = TaskEventResult(
        success: true,
        instanceId: 'inst-1',
        actionApplied: 'completed',
        createdNewInstance: true,
        message: 'Processed',
      );

      final json = result.toJson();
      final restored = TaskEventResult.fromJson(json);
      expect(restored.success, isTrue);
      expect(restored.instanceId, equals('inst-1'));
      expect(restored.actionApplied, equals('completed'));
      expect(restored.createdNewInstance, isTrue);
      expect(restored.message, equals('Processed'));

      final minimal = TaskEventResult.fromJson(const {});
      expect(minimal.success, isFalse);
      expect(minimal.actionApplied, isEmpty);
      expect(minimal.instanceId, isNull);
      expect(minimal.toJson(), equals({'success': false, 'actionApplied': ''}));
    });
  });
}
