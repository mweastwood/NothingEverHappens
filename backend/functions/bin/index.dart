import 'dart:js' as js;
import 'dart:js_interop';
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
      } catch (error) {
        logError('Scheduled task history cleanup failed:', error);
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
      } catch (error) {
        logError('Scheduled family tasks evaluation failed:', error);
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
      return processHistoryCleanup(
        db,
        now,
        batchLimit ?? 500,
        maxBatches ?? 20,
      ).then((res) => js.JsObject.jsify(res.toJson())).toJS;
    }),
  );

  // 8. export processFamilyScheduleDirect for testing & direct invocation parity
  exportFunction(
    'processFamilyScheduleDirect',
    js.allowInterop(([dynamic jsDb, String? familyId, dynamic now]) {
      final db = getFirebaseAdminDb(jsDb);
      return processFamilyScheduleDirect(
        db,
        familyId: familyId,
        now: now,
      ).then((res) {
        final json = res is FamilyScheduleSummary
            ? res.toJson()
            : (res as FamilySchedulerResult).toJson();
        return js.JsObject.jsify(json);
      }).toJS;
    }),
  );
}
