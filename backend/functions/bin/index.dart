import 'dart:js' as js;
import 'dart:js_interop';
import 'package:functions/src/handlers/account_deletion.dart';
import 'package:functions/src/handlers/cleanup_history.dart';
import 'package:functions/src/handlers/status.dart';
import 'package:functions/src/handlers/task_events.dart';
import 'package:functions/src/interop/firebase_admin.dart';
import 'package:functions/src/interop/firebase_functions.dart';
import 'package:functions/src/interop/node_interop.dart';

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

  // 5. export processHistoryCleanup for testing & direct invocation parity
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
}
