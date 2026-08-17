import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/utils/pii_sanitizer.dart';

class _CustomSerializable {
  final String name;
  final String email;
  _CustomSerializable(this.name, this.email);

  Map<String, dynamic> toJson() => {'displayName': name, 'userEmail': email};
}

class _NonSerializablePii {
  final String value;
  _NonSerializablePii(this.value);

  @override
  String toString() => value;
}

void main() {
  group('PiiSanitizer', () {
    group('maskEmail', () {
      test('masks emails and handles edge cases', () {
        expect(PiiSanitizer.maskEmail(null), isNull);
        expect(PiiSanitizer.maskEmail(''), '');
        expect(PiiSanitizer.maskEmail('   '), '');
        expect(
          PiiSanitizer.maskEmail('john.doe@example.com'),
          'j***@example.com',
        );
        expect(PiiSanitizer.maskEmail('a@b.com'), 'a***@b.com');
        expect(PiiSanitizer.maskEmail('invalid-email'), '***');
        expect(PiiSanitizer.maskEmail('one@two@three.com'), '***');
        expect(PiiSanitizer.maskEmail('@domain.com'), '***@domain.com');
      });
    });

    group('maskPii', () {
      test('masks PII strings and handles edge cases', () {
        expect(PiiSanitizer.maskPii(null), isNull);
        expect(PiiSanitizer.maskPii(''), '');
        expect(PiiSanitizer.maskPii('   '), '');
        expect(PiiSanitizer.maskPii('John Doe'), 'J***');
        expect(PiiSanitizer.maskPii('+15551234567'), '+***');
        expect(PiiSanitizer.maskPii('https://example.com/avatar.jpg'), 'h***');
      });
    });

    group('sanitize', () {
      test('handles primitives, strings, and types', () {
        expect(PiiSanitizer.sanitize(null), isNull);
        expect(PiiSanitizer.sanitize(42), 42);
        expect(PiiSanitizer.sanitize(3.14), 3.14);
        expect(PiiSanitizer.sanitize(true), isTrue);
        expect(PiiSanitizer.sanitize('plain text'), 'plain text');
        expect(
          PiiSanitizer.sanitize('user@example.com', isEmailKey: true),
          'u***@example.com',
        );
        expect(PiiSanitizer.sanitize('Sensitive Info', isPiiKey: true), 'S***');
      });

      test('preserves role and status values when isPiiKey is true', () {
        final rolesAndStatuses = [
          'admin',
          'owner',
          'member',
          'parent',
          'non-parent',
          'viewer',
          'editor',
          'creator',
          'active',
          'pending',
          'accepted',
          'declined',
          'inactive',
        ];

        for (final val in rolesAndStatuses) {
          expect(
            PiiSanitizer.sanitize(val, isPiiKey: true),
            val,
            reason: 'Expected $val to be preserved',
          );
          expect(
            PiiSanitizer.sanitize('  $val  ', isPiiKey: true),
            '  $val  ',
            reason: 'Expected trimmed match of $val to be preserved',
          );
        }
      });

      test('converts complex data types into JSON-encodable structures', () {
        final now = DateTime.utc(2026, 8, 17, 12, 0, 0);
        final timestamp = Timestamp.fromDate(now);
        const civilDay = CivilDay(year: 2026, month: 8, day: 17);
        const relativeTime = RelativeTime(
          dayOffset: 2,
          time: TimeOfDay(hour: 15, minute: 45),
        );
        const timeOfDay = TimeOfDay(hour: 9, minute: 30);
        const duration = Duration(minutes: 90);
        const geoPoint = GeoPoint(37.7749, -122.4194);

        expect(PiiSanitizer.sanitize(now), '2026-08-17T12:00:00.000Z');
        expect(PiiSanitizer.sanitize(timestamp), '2026-08-17T12:00:00.000Z');
        expect(PiiSanitizer.sanitize(civilDay), {
          'year': 2026,
          'month': 8,
          'day': 17,
        });
        expect(PiiSanitizer.sanitize(relativeTime), {
          'dayOffset': 2,
          'hour': 15,
          'minute': 45,
        });
        expect(PiiSanitizer.sanitize(timeOfDay), {'hour': 9, 'minute': 30});
        expect(PiiSanitizer.sanitize(TaskPriority.high), 'high');
        expect(PiiSanitizer.sanitize(duration), 5400000);
        expect(PiiSanitizer.sanitize(geoPoint), {
          'latitude': 37.7749,
          'longitude': -122.4194,
        });
      });

      test(
        'recursively sanitizes maps and lists while respecting PII rules',
        () {
          final rawMap = {
            'taskId': 'T-100',
            'userId': 'U-200',
            'member_ids': ['M-1', 'M-2'],
            'role': 'owner',
            'status': 'active',
            'displayName': 'Alice Smith',
            'email': 'alice@example.com',
            'phone_number': '+15551234567',
            'avatar': 'https://example.com/alice.png',
            'address': '123 Main St',
            'bio': 'Software engineer',
            'nested': {
              'customEmail': 'nested@example.com',
              'sender': 'Bob Jones',
              'recipient': 'Charlie Brown',
              'notes': 'Normal notes',
            },
            'list': [
              {'fullName': 'David Miller', 'email': 'david@example.com'},
              'simple string',
            ],
          };

          final sanitized =
              PiiSanitizer.sanitize(rawMap) as Map<String, dynamic>;

          expect(sanitized['taskId'], 'T-100');
          expect(sanitized['userId'], 'U-200');
          expect(sanitized['member_ids'], ['M-1', 'M-2']);
          expect(sanitized['role'], 'owner');
          expect(sanitized['status'], 'active');
          expect(sanitized['displayName'], 'A***');
          expect(sanitized['email'], 'a***@example.com');
          expect(sanitized['phone_number'], '+***');
          expect(sanitized['avatar'], 'h***');
          expect(sanitized['address'], '1***');
          expect(sanitized['bio'], 'S***');
          expect(sanitized['nested']['customEmail'], 'n***@example.com');
          expect(sanitized['nested']['sender'], 'B***');
          expect(sanitized['nested']['recipient'], 'C***');
          expect(sanitized['nested']['notes'], 'Normal notes');
          expect(sanitized['list'][0]['fullName'], 'D***');
          expect(sanitized['list'][0]['email'], 'd***@example.com');
          expect(sanitized['list'][1], 'simple string');
        },
      );

      test('supports custom objects with toJson and fallback toString', () {
        final customObj = _CustomSerializable('Jane Doe', 'jane@example.com');
        final sanitizedCustom = PiiSanitizer.sanitize(customObj);
        expect(sanitizedCustom, {
          'displayName': 'J***',
          'userEmail': 'j***@example.com',
        });

        final nonSerializable = _NonSerializablePii('Secret Name');
        final sanitizedNonSerial = PiiSanitizer.sanitize(
          nonSerializable,
          isPiiKey: true,
        );
        expect(sanitizedNonSerial, 'S***');

        final nonSerialEmail = _NonSerializablePii('secret@test.com');
        final sanitizedEmail = PiiSanitizer.sanitize(
          nonSerialEmail,
          isEmailKey: true,
        );
        expect(sanitizedEmail, 's***@test.com');
      });

      test('sanitizeForJson alias delegates directly to sanitize', () {
        final input = {'displayName': 'Test User', 'email': 'test@test.com'};
        expect(
          PiiSanitizer.sanitizeForJson(input),
          PiiSanitizer.sanitize(input),
        );
      });
    });
  });
}
