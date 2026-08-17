import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
import 'package:nothing_ever_happens/logic/app_state_exporter.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/widgets/debug_state_share_helper.dart';

import '../test_helper.dart';

class FailingAppStateExporter extends AppStateExporter {
  FailingAppStateExporter({required super.hiveDataSource});

  @override
  Future<String> exportStateJson({bool pretty = true}) async {
    throw Exception('Simulated export error');
  }
}

void main() {
  group('DebugStateShareHelper', () {
    late HiveLocalDataSource localDataSource;

    setUp(() {
      localDataSource = HiveLocalDataSource();
      localDataSource.isFallbackInMemoryMode = true;
    });

    testWidgets('completes fast without hanging progress indicator', (
      WidgetTester tester,
    ) async {
      final exporter = AppStateExporter(
        firestore: null,
        hiveDataSource: localDataSource,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => DebugStateShareHelper.shareDebugState(
                    context,
                    exporter: exporter,
                  ),
                  child: const Text('Share'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'calls injected fileSaver with json string and formatted filename',
      (WidgetTester tester) async {
        String? capturedContent;
        String? capturedFileName;
        String? capturedMimeType;

        final exporter = AppStateExporter(
          firestore: null,
          hiveDataSource: localDataSource,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => DebugStateShareHelper.shareDebugState(
                      context,
                      exporter: exporter,
                      fileSaver:
                          (content, fileName, {mimeType = 'application/json'}) {
                            capturedContent = content;
                            capturedFileName = fileName;
                            capturedMimeType = mimeType;
                          },
                    ),
                    child: const Text('Export'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        expect(capturedContent, isNotNull);
        final decoded = jsonDecode(capturedContent!);
        expect(decoded['exportMetadata'], isNotNull);
        expect(capturedFileName, matches(r'^debug_app_state_\d+\.json$'));
        expect(capturedMimeType, 'application/json');
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'falls back to clipboard and shows SnackBar when fileSaver throws',
      (WidgetTester tester) async {
        final List<Map<String, dynamic>> clipboardStore = [];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'Clipboard.setData') {
                clipboardStore.add(
                  methodCall.arguments as Map<String, dynamic>,
                );
                return null;
              }
              return null;
            });

        final exporter = AppStateExporter(
          firestore: null,
          hiveDataSource: localDataSource,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => DebugStateShareHelper.shareDebugState(
                      context,
                      exporter: exporter,
                      fileSaver:
                          (content, fileName, {mimeType = 'application/json'}) {
                            throw Exception('FileSaver web download failed');
                          },
                    ),
                    child: const Text('Export'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        expect(clipboardStore, isNotEmpty);
        final copiedText = clipboardStore.last['text'] as String;
        final decoded = jsonDecode(copiedText);
        expect(decoded['exportMetadata'], isNotNull);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets('logs export initiated and completed events into AppLogger', (
      WidgetTester tester,
    ) async {
      final logger = AppLogger();
      final exporter = AppStateExporter(
        firestore: null,
        hiveDataSource: localDataSource,
        logger: logger,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => DebugStateShareHelper.shareDebugState(
                    context,
                    exporter: exporter,
                    logger: logger,
                  ),
                  child: const Text('Export'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final events = logger.getEvents();
      expect(events.length, 2);
      expect(events[0].category, 'export');
      expect(events[0].message, 'Debug state export initiated');
      expect(events[1].category, 'export');
      expect(events[1].message, 'Debug state export completed');
    });

    testWidgets('routes error to ErrorHandler when export fails', (
      WidgetTester tester,
    ) async {
      final exporter = FailingAppStateExporter(hiveDataSource: localDataSource);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => DebugStateShareHelper.shareDebugState(
                    context,
                    exporter: exporter,
                  ),
                  child: const Text('Export'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Error dialog should be presented
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
