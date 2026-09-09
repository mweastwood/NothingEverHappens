import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/notification_helper.dart';

class FakeNotificationJsObject implements NotificationJsObject {
  @override
  String? permission;
  int requestPermissionCallCount = 0;

  FakeNotificationJsObject({this.permission});

  @override
  void requestPermission() {
    requestPermissionCallCount++;
  }
}

class FakeNotificationJsContext implements NotificationJsContext {
  final Set<String> _properties;
  NotificationJsObject? notificationObject;
  final List<String> evaluatedScripts = [];

  FakeNotificationJsContext({Set<String>? properties, this.notificationObject})
    : _properties = properties ?? {};

  void defineProperty(String name) => _properties.add(name);
  void removeProperty(String name) => _properties.remove(name);

  @override
  bool hasProperty(String property) => _properties.contains(property);

  @override
  NotificationJsObject? getNotification() => notificationObject;

  @override
  void eval(String script) {
    evaluatedScripts.add(script);
  }
}

void main() {
  group('Native Stub Safety', () {
    test(
      'requestWebNotificationPermission executes cleanly on native platform',
      () {
        expect(() => requestWebNotificationPermission(), returnsNormally);
      },
    );

    test('showWebNotification executes cleanly on native platform', () {
      expect(
        () => showWebNotification('Test Title', 'Test Body'),
        returnsNormally,
      );
    });

    test('stubs accept optional context parameter without throwing', () {
      final fakeContext = FakeNotificationJsContext();
      expect(
        () => requestWebNotificationPermission(fakeContext),
        returnsNormally,
      );
      expect(
        () => showWebNotification('Title', 'Body', fakeContext),
        returnsNormally,
      );
    });
  });

  group('Notification Sanitization & Script Generation', () {
    test('escapeNotificationText escapes single quotes correctly', () {
      expect(
        escapeNotificationText("Don't miss this"),
        equals("Don\\'t miss this"),
      );
      expect(
        escapeNotificationText("Today's schedule for Alice's task"),
        equals("Today\\'s schedule for Alice\\'s task"),
      );
      expect(
        escapeNotificationText("No quotes here"),
        equals("No quotes here"),
      );
      expect(escapeNotificationText(''), equals(''));
    });

    test('escapeNotificationText leaves double quotes untouched', () {
      expect(
        escapeNotificationText('Double "quoted" text'),
        equals('Double "quoted" text'),
      );
    });

    test(
      'buildNotificationScript constructs valid Notification instantiation code',
      () {
        final script = buildNotificationScript(
          'Meeting Alert',
          'Team sync in 5 minutes',
        );
        expect(
          script,
          equals(
            "new Notification('Meeting Alert', { body: 'Team sync in 5 minutes' });",
          ),
        );
      },
    );

    test('buildNotificationScript escapes single quotes in title and body', () {
      final script = buildNotificationScript(
        "Don't forget",
        "It's time for lunch!",
      );
      expect(
        script,
        equals(
          "new Notification('Don\\'t forget', { body: 'It\\'s time for lunch!' });",
        ),
      );
    });

    test('buildNotificationScript handles empty title and body', () {
      final script = buildNotificationScript('', '');
      expect(script, equals("new Notification('', { body: '' });"));
    });
  });

  group(
    'Web Permission Check Logic (executeRequestWebNotificationPermission)',
    () {
      test(
        'does nothing when Notification property is missing from context',
        () {
          final context = FakeNotificationJsContext();
          final notifObj = FakeNotificationJsObject(permission: 'default');
          context.notificationObject = notifObj;

          executeRequestWebNotificationPermission(context);

          expect(notifObj.requestPermissionCallCount, equals(0));
        },
      );

      test(
        'does nothing when Notification property exists but getNotification returns null',
        () {
          final context = FakeNotificationJsContext(
            properties: {'Notification'},
          );
          context.notificationObject = null;

          expect(
            () => executeRequestWebNotificationPermission(context),
            returnsNormally,
          );
        },
      );

      test('does not request permission if already granted', () {
        final notifObj = FakeNotificationJsObject(permission: 'granted');
        final context = FakeNotificationJsContext(
          properties: {'Notification'},
          notificationObject: notifObj,
        );

        executeRequestWebNotificationPermission(context);

        expect(notifObj.requestPermissionCallCount, equals(0));
      });

      test('requests permission when status is default', () {
        final notifObj = FakeNotificationJsObject(permission: 'default');
        final context = FakeNotificationJsContext(
          properties: {'Notification'},
          notificationObject: notifObj,
        );

        executeRequestWebNotificationPermission(context);

        expect(notifObj.requestPermissionCallCount, equals(1));
      });

      test('requests permission when status is denied', () {
        final notifObj = FakeNotificationJsObject(permission: 'denied');
        final context = FakeNotificationJsContext(
          properties: {'Notification'},
          notificationObject: notifObj,
        );

        executeRequestWebNotificationPermission(context);

        expect(notifObj.requestPermissionCallCount, equals(1));
      });

      test('requests permission when permission is null', () {
        final notifObj = FakeNotificationJsObject(permission: null);
        final context = FakeNotificationJsContext(
          properties: {'Notification'},
          notificationObject: notifObj,
        );

        executeRequestWebNotificationPermission(context);

        expect(notifObj.requestPermissionCallCount, equals(1));
      });
    },
  );

  group('Notification Dispatch (executeShowWebNotification)', () {
    test('does not eval when Notification property is missing', () {
      final notifObj = FakeNotificationJsObject(permission: 'granted');
      final context = FakeNotificationJsContext(notificationObject: notifObj);

      executeShowWebNotification(context, 'Title', 'Body');

      expect(context.evaluatedScripts, isEmpty);
    });

    test(
      'does not throw or eval when Notification property exists but getNotification is null',
      () {
        final context = FakeNotificationJsContext(properties: {'Notification'});
        context.notificationObject = null;

        expect(
          () => executeShowWebNotification(context, 'Title', 'Body'),
          returnsNormally,
        );
        expect(context.evaluatedScripts, isEmpty);
      },
    );

    test('evaluates notification script when permission is granted', () {
      final notifObj = FakeNotificationJsObject(permission: 'granted');
      final context = FakeNotificationJsContext(
        properties: {'Notification'},
        notificationObject: notifObj,
      );

      executeShowWebNotification(
        context,
        "Reminder: Don't forget",
        "It's 2 PM",
      );

      expect(context.evaluatedScripts.length, equals(1));
      expect(
        context.evaluatedScripts.first,
        equals(
          "new Notification('Reminder: Don\\'t forget', { body: 'It\\'s 2 PM' });",
        ),
      );
    });

    test(
      'does not evaluate notification script when permission is default',
      () {
        final notifObj = FakeNotificationJsObject(permission: 'default');
        final context = FakeNotificationJsContext(
          properties: {'Notification'},
          notificationObject: notifObj,
        );

        executeShowWebNotification(context, 'Title', 'Body');

        expect(context.evaluatedScripts, isEmpty);
      },
    );

    test('does not evaluate notification script when permission is denied', () {
      final notifObj = FakeNotificationJsObject(permission: 'denied');
      final context = FakeNotificationJsContext(
        properties: {'Notification'},
        notificationObject: notifObj,
      );

      executeShowWebNotification(context, 'Title', 'Body');

      expect(context.evaluatedScripts, isEmpty);
    });

    test('does not evaluate notification script when permission is null', () {
      final notifObj = FakeNotificationJsObject(permission: null);
      final context = FakeNotificationJsContext(
        properties: {'Notification'},
        notificationObject: notifObj,
      );

      executeShowWebNotification(context, 'Title', 'Body');

      expect(context.evaluatedScripts, isEmpty);
    });
  });
}
