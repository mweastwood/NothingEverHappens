import 'dart:convert';
import 'dart:js' as js;
import 'package:functions/src/handlers/account_deletion.dart';
import 'package:functions/src/handlers/cleanup_history.dart';
import 'package:functions/src/handlers/family_scheduler.dart';
import 'package:functions/src/handlers/status.dart';
import 'package:functions/src/handlers/task_events.dart';
import 'package:functions/src/interop/firebase_admin.dart';
import 'package:functions/src/interop/firebase_functions.dart';
import 'package:functions/src/interop/node_interop.dart';
import 'package:functions/src/services/family_scheduler_service.dart';

void main() {
  initializeFirebaseAdmin();

  // 1. deleteUserAccount endpoint
  final deleteUserAccountFn = onRequest(
    {
      'cors': true,
      'memory': '256MiB',
    },
    (req, res) async {
      await handleDeleteUserAccount(req, res);
    },
  );
  exportFunction('deleteUserAccount', deleteUserAccountFn);

  // 2. reportExternalTaskEvent endpoint
  final reportExternalTaskEventFn = onRequest(
    {
      'cors': true,
      'memory': '256MiB',
    },
    (req, res) async {
      await handleReportExternalTaskEvent(req, res);
    },
  );
  exportFunction('reportExternalTaskEvent', reportExternalTaskEventFn);

  // 3. cleanupExpiredHistory scheduled function
  final cleanupExpiredHistoryFn = onSchedule(
    {
      'schedule': '0 3 * * *',
      'timeZone': 'UTC',
      'memory': '256MiB',
      'timeoutSeconds': 120,
    },
    (event) async {
      logInfo('Starting scheduled task history cleanup...');
      try {
        final db = getFirebaseAdminDb();
        final result = await processHistoryCleanup(db);
        logInfo(
          'Scheduled task history cleanup finished successfully. Total deleted: ${result.totalDeleted}, Batches: ${result.batchesProcessed}, Duration: ${result.durationMs}ms',
        );
      } catch (error, stackTrace) {
        logError(
          'Scheduled task history cleanup failed: $error\n$stackTrace',
          error,
        );
        rethrow;
      }
    },
  );
  exportFunction('cleanupExpiredHistory', cleanupExpiredHistoryFn);

  // 4. status endpoint
  final statusFn = onRequest(
    {
      'cors': true,
      'memory': '128MiB',
    },
    (req, res) async {
      await handleStatus(req, res);
    },
  );
  exportFunction('status', statusFn);

  // 5. scheduleFamilyTasks scheduled function (hourly)
  final scheduleFamilyTasksFn = onSchedule(
    {
      'schedule': '0 * * * *',
      'timeZone': 'UTC',
      'memory': '256MiB',
      'timeoutSeconds': 300,
    },
    (event) async {
      logInfo('Starting scheduled family tasks evaluation...');
      try {
        final db = getFirebaseAdminDb();
        final service = FamilySchedulerService(db);
        final result = await service.processAllFamilies();
        logInfo(
          'Scheduled family tasks evaluation finished successfully. Families: ${result.familiesProcessed}, Spawned: ${result.totalInstancesSpawned}, Updated: ${result.totalInstancesUpdated}, Deleted: ${result.totalInstancesDeleted}, Schedules: ${result.totalSchedulesUpdated}, Duration: ${result.durationMs}ms',
        );
      } catch (error, stackTrace) {
        logError(
          'Scheduled family tasks evaluation failed: $error\n$stackTrace',
          error,
        );
        rethrow;
      }
    },
  );
  exportFunction('scheduleFamilyTasks', scheduleFamilyTasksFn);

  // 6. processFamilySchedule HTTP endpoint
  final processFamilyScheduleFn = onRequest(
    {
      'cors': true,
      'memory': '256MiB',
      'timeoutSeconds': 120,
    },
    (req, res) async {
      await handleProcessFamilySchedule(req, res);
    },
  );
  exportFunction('processFamilySchedule', processFamilyScheduleFn);

  // 7. export processHistoryCleanup for testing & direct invocation parity
  exportFunction(
    'processHistoryCleanup',
    js.allowInterop((
        [dynamic jsDb, dynamic now, int? batchLimit, int? maxBatches]) {
      final db = getFirebaseAdminDb(jsDb);
      return futureToJsPromise(processHistoryCleanup(
        db,
        now,
        batchLimit ?? 500,
        maxBatches ?? 20,
      ).then((res) => res.toJson()));
    }),
  );

  // 8. export processFamilyScheduleDirect for testing & direct invocation parity
  exportFunction(
    'processFamilyScheduleDirect',
    js.allowInterop(([dynamic jsDb, String? familyId, dynamic now]) {
      final db = getFirebaseAdminDb(jsDb);
      return futureToJsPromise(processFamilyScheduleDirect(
        db,
        familyId: familyId,
        now: now,
      ).then((res) {
        return res is FamilyScheduleSummary
            ? res.toJson()
            : (res as FamilySchedulerResult).toJson();
      }));
    }),
  );

  // 9. export processExternalTaskEventDirect for testing & direct invocation parity
  exportFunction(
    'processExternalTaskEventDirect',
    js.allowInterop(([dynamic jsDb, dynamic rawEvent, dynamic now]) {
      return futureToJsPromise((() async {
        final db = getFirebaseAdminDb(jsDb);
        Map<String, dynamic> eventMap;
        if (rawEvent is String) {
          eventMap = jsonDecode(rawEvent) as Map<String, dynamic>;
        } else if (rawEvent is Map) {
          eventMap = Map<String, dynamic>.from(rawEvent);
        } else if (rawEvent != null) {
          final jsonStr =
              js.context['JSON'].callMethod('stringify', [rawEvent]) as String?;
          eventMap = jsonStr != null
              ? jsonDecode(jsonStr) as Map<String, dynamic>
              : <String, dynamic>{};
        } else {
          eventMap = <String, dynamic>{};
        }
        final validation = validateTaskEvent(eventMap);
        if (!validation.valid || validation.event == null) {
          throw ArgumentError(validation.error ?? 'Invalid task event');
        }
        DateTime? nowDate;
        if (now is DateTime) {
          nowDate = now.toUtc();
        } else if (now is String) {
          final asNum = num.tryParse(now);
          nowDate = asNum != null
              ? DateTime.fromMillisecondsSinceEpoch(asNum.toInt(), isUtc: true)
              : DateTime.tryParse(now)?.toUtc();
        } else if (now is num) {
          nowDate =
              DateTime.fromMillisecondsSinceEpoch(now.toInt(), isUtc: true);
        } else if (now != null) {
          try {
            final jsonStr =
                js.context['JSON'].callMethod('stringify', [now]) as String?;
            if (jsonStr != null &&
                jsonStr.length >= 2 &&
                jsonStr.startsWith('"') &&
                jsonStr.endsWith('"')) {
              nowDate =
                  DateTime.tryParse(jsonStr.substring(1, jsonStr.length - 1))
                      ?.toUtc();
            }
          } catch (_) {}
        }
        final result = await processExternalTaskEvent(
          db,
          validation.event!,
          now: nowDate,
        );
        return result.toJson();
      })());
    }),
  );

  // 10. export queryWhereDirect for testing & query conversion verification parity
  exportFunction(
    'queryWhereDirect',
    js.allowInterop(([dynamic jsDb, dynamic whereArgs]) {
      return futureToJsPromise((() async {
        final db = getFirebaseAdminDb(jsDb);
        Query query = db.collection('test_col');
        List<dynamic> clauses = [];
        final jsonStr = whereArgs is String
            ? whereArgs
            : js.context['JSON'].callMethod('stringify', [whereArgs])
                as String?;
        if (jsonStr != null) {
          final decoded = jsonDecode(jsonStr);
          if (decoded is List) {
            clauses = decoded;
          }
        }
        for (final clause in clauses) {
          if (clause is Map) {
            final field = clause['field']?.toString() ?? 'field';
            final op = clause['op']?.toString() ?? '==';
            dynamic val = clause['value'];
            if (clause['isDateTime'] == true && val != null) {
              val = val is num
                  ? DateTime.fromMillisecondsSinceEpoch(val.toInt(),
                      isUtc: true)
                  : DateTime.tryParse(val.toString())?.toUtc();
            } else if (clause['isNonStringKeys'] == true) {
              val = {1: 'first', 2: 'second'};
            }
            query = query.where(field, op, val);
          }
        }
        return true;
      })());
    }),
  );
}
