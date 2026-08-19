import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/remote_config_service.dart';

class FakeRemoteConfigValue implements RemoteConfigValue {
  final String _value;
  @override
  final ValueSource source;

  FakeRemoteConfigValue(this._value, {this.source = ValueSource.valueRemote});

  @override
  bool asBool() => _value.toLowerCase() == 'true' || _value == '1';

  @override
  double asDouble() => double.tryParse(_value) ?? 0.0;

  @override
  int asInt() => int.tryParse(_value) ?? 0;

  @override
  String asString() => _value;
}

class FakeFirebaseRemoteConfig extends Fake implements FirebaseRemoteConfig {
  RemoteConfigSettings _settings = RemoteConfigSettings(
    fetchTimeout: const Duration(minutes: 1),
    minimumFetchInterval: const Duration(hours: 12),
  );
  Map<String, dynamic> defaults = {};
  final Map<String, RemoteConfigValue> parameters = {};
  bool fetchAndActivateResult = true;
  bool shouldThrowOnFetch = false;

  @override
  RemoteConfigSettings get settings => _settings;

  @override
  Future<void> setConfigSettings(
    RemoteConfigSettings remoteConfigSettings,
  ) async {
    _settings = remoteConfigSettings;
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaultParameters) async {
    defaults = Map.from(defaultParameters);
  }

  @override
  Future<bool> fetchAndActivate() async {
    if (shouldThrowOnFetch) {
      throw Exception('Network timeout');
    }
    return fetchAndActivateResult;
  }

  @override
  bool getBool(String key) {
    if (parameters.containsKey(key)) {
      return parameters[key]!.asBool();
    }
    final def = defaults[key];
    if (def is bool) return def;
    if (def is String) return def.toLowerCase() == 'true';
    return false;
  }

  @override
  String getString(String key) {
    if (parameters.containsKey(key)) {
      return parameters[key]!.asString();
    }
    final def = defaults[key];
    return def?.toString() ?? '';
  }

  @override
  int getInt(String key) {
    if (parameters.containsKey(key)) {
      return parameters[key]!.asInt();
    }
    final def = defaults[key];
    if (def is int) return def;
    if (def is num) return def.toInt();
    if (def is String) return int.tryParse(def) ?? 0;
    return 0;
  }

  @override
  double getDouble(String key) {
    if (parameters.containsKey(key)) {
      return parameters[key]!.asDouble();
    }
    final def = defaults[key];
    if (def is double) return def;
    if (def is num) return def.toDouble();
    if (def is String) return double.tryParse(def) ?? 0.0;
    return 0.0;
  }

  @override
  Map<String, RemoteConfigValue> getAll() => Map.unmodifiable(parameters);
}

void main() {
  group('RemoteConfigService Unit Tests', () {
    late FakeFirebaseRemoteConfig fakeRemoteConfig;

    setUp(() {
      fakeRemoteConfig = FakeFirebaseRemoteConfig();
    });

    test(
      'FirebaseRemoteConfigService initializes settings and defaults',
      () async {
        final service = FirebaseRemoteConfigService(
          remoteConfig: fakeRemoteConfig,
        );

        await service.initialize(
          defaultParameters: {
            'experiment_feature_enabled': true,
            'max_retries': 3,
            'banner_text': 'Welcome to Beta',
            'discount_rate': 0.15,
          },
        );

        expect(fakeRemoteConfig.settings, isNotNull);
        expect(fakeRemoteConfig.defaults['experiment_feature_enabled'], true);
        expect(fakeRemoteConfig.defaults['max_retries'], 3);
        expect(service.getBool('experiment_feature_enabled'), true);
        expect(service.getInt('max_retries'), 3);
        expect(service.getString('banner_text'), 'Welcome to Beta');
        expect(service.getDouble('discount_rate'), 0.15);
      },
    );

    test(
      'FirebaseRemoteConfigService resolves remote parameters over defaults',
      () async {
        final service = FirebaseRemoteConfigService(
          remoteConfig: fakeRemoteConfig,
        );

        await service.initialize(
          defaultParameters: {
            'experiment_feature_enabled': false,
            'max_retries': 1,
          },
        );

        fakeRemoteConfig.parameters['experiment_feature_enabled'] =
            FakeRemoteConfigValue('true');
        fakeRemoteConfig.parameters['max_retries'] = FakeRemoteConfigValue('5');
        fakeRemoteConfig.parameters['experiment_group'] = FakeRemoteConfigValue(
          'variant_b',
        );
        fakeRemoteConfig.parameters['threshold'] = FakeRemoteConfigValue(
          '4.25',
        );

        expect(service.getBool('experiment_feature_enabled'), true);
        expect(service.getInt('max_retries'), 5);
        expect(service.getString('experiment_group'), 'variant_b');
        expect(service.getDouble('threshold'), 4.25);
      },
    );

    test('fetchAndActivate handles success and failure gracefully', () async {
      final service = FirebaseRemoteConfigService(
        remoteConfig: fakeRemoteConfig,
      );

      fakeRemoteConfig.fetchAndActivateResult = true;
      final activated = await service.fetchAndActivate();
      expect(activated, isTrue);

      fakeRemoteConfig.shouldThrowOnFetch = true;
      final failedResult = await service.fetchAndActivate();
      expect(failedResult, isFalse);
    });

    test(
      'FirebaseRemoteConfigService with null remoteConfig falls back safely',
      () async {
        final service = FirebaseRemoteConfigService(remoteConfig: null);

        await service.initialize(
          defaultParameters: {
            'flag': true,
            'title': 'Local Fallback',
            'count': 10,
            'ratio': 0.5,
          },
        );

        expect(await service.fetchAndActivate(), isFalse);
        expect(service.getBool('flag'), isTrue);
        expect(service.getString('title'), 'Local Fallback');
        expect(service.getInt('count'), 10);
        expect(service.getDouble('ratio'), 0.5);
        expect(service.getAll()['title'], 'Local Fallback');
      },
    );

    test(
      'NoOpRemoteConfigService provides safe defaults and does not throw',
      () async {
        final service = NoOpRemoteConfigService(
          defaultParameters: {
            'is_ab_test_active': true,
            'header_variant': 'modern',
            'slot_limit': 12,
            'opacity': 0.8,
          },
        );

        expect(await service.fetchAndActivate(), isFalse);
        expect(service.getBool('is_ab_test_active'), isTrue);
        expect(service.getString('header_variant'), 'modern');
        expect(service.getInt('slot_limit'), 12);
        expect(service.getDouble('opacity'), 0.8);
        expect(service.getBool('unknown_flag'), isFalse);
        expect(service.getString('unknown_str'), '');
        expect(service.getInt('unknown_num'), 0);
        expect(service.getDouble('unknown_double'), 0.0);

        await service.initialize(defaultParameters: {'new_param': 'test'});
        expect(service.getString('new_param'), 'test');
      },
    );

    test('remoteConfigServiceProvider returns a valid RemoteConfigService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(remoteConfigServiceProvider);
      expect(service, isA<RemoteConfigService>());
    });
  });

  group('A/B Testing Widget Tests with RemoteConfigService', () {
    testWidgets('Renders Control Group UI when flag is false', (tester) async {
      final noOpService = NoOpRemoteConfigService(
        defaultParameters: {'enable_new_task_layout': false},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remoteConfigServiceProvider.overrideWithValue(noOpService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final remoteConfig = ref.watch(remoteConfigServiceProvider);
                  final useNewLayout = remoteConfig.getBool(
                    'enable_new_task_layout',
                  );
                  return Text(
                    useNewLayout
                        ? 'Variant: New Task Layout'
                        : 'Variant: Classic Layout',
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Variant: Classic Layout'), findsOneWidget);
      expect(find.text('Variant: New Task Layout'), findsNothing);
    });

    testWidgets('Renders Experiment Variant A UI when flag is true', (
      tester,
    ) async {
      final noOpService = NoOpRemoteConfigService(
        defaultParameters: {'enable_new_task_layout': true},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remoteConfigServiceProvider.overrideWithValue(noOpService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final remoteConfig = ref.watch(remoteConfigServiceProvider);
                  final useNewLayout = remoteConfig.getBool(
                    'enable_new_task_layout',
                  );
                  return Text(
                    useNewLayout
                        ? 'Variant: New Task Layout'
                        : 'Variant: Classic Layout',
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Variant: New Task Layout'), findsOneWidget);
      expect(find.text('Variant: Classic Layout'), findsNothing);
    });
  });
}
