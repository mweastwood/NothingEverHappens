import 'package:meta/meta.dart';
import '../interop/firebase_admin.dart';
import '../interop/node_interop.dart';

@immutable
class HistoryCleanupResult {
  final bool success;
  final int totalDeleted;
  final int batchesProcessed;
  final int durationMs;

  const HistoryCleanupResult({
    required this.success,
    required this.totalDeleted,
    required this.batchesProcessed,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'totalDeleted': totalDeleted,
      'batchesProcessed': batchesProcessed,
      'durationMs': durationMs,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HistoryCleanupResult &&
        other.success == success &&
        other.totalDeleted == totalDeleted &&
        other.batchesProcessed == batchesProcessed &&
        other.durationMs == durationMs;
  }

  @override
  int get hashCode => Object.hash(
        success,
        totalDeleted,
        batchesProcessed,
        durationMs,
      );
}

/// Default retention window (in days) for resolved (`completed` / `skipped`) task instances.
const int defaultHistoryRetentionDays = 90;

DateTime _parseCleanupReferenceNow(dynamic now) {
  if (now == null) return DateTime.now().toUtc();
  if (now is DateTime) return now.toUtc();
  if (now is num) {
    return DateTime.fromMillisecondsSinceEpoch(now.toInt(), isUtc: true);
  }
  final str = now.toString().trim();
  if (str.isEmpty) return DateTime.now().toUtc();
  final asInt = int.tryParse(str);
  if (asInt != null) {
    return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
  }
  return DateTime.tryParse(str)?.toUtc() ?? DateTime.now().toUtc();
}

/// Core handler to process batch deletion of expired resolved task instances across Firestore.
/// Queries `db.collectionGroup("instances")` for resolved (`completed` or `skipped`) documents
/// whose `updatedAt` timestamp is on or before `now - retentionDays` (default 90 days).
///
/// [db]: Firestore database instance.
/// [now]: Reference timestamp for computing the retention cutoff.
/// [batchLimit]: Number of documents to delete per batch (max 500 per Firebase guidelines).
/// [maxBatches]: Safe limit on number of batch iterations per execution to prevent timeouts.
/// [retentionDays]: Retention window in days before resolved instances expire (defaults to 90).
Future<HistoryCleanupResult> processHistoryCleanup(
  FirestoreDatabase db, [
  dynamic now,
  int batchLimit = 500,
  int maxBatches = 20,
  int retentionDays = defaultHistoryRetentionDays,
]) async {
  final referenceNow = _parseCleanupReferenceNow(now);
  final cutoffDate = referenceNow.subtract(Duration(days: retentionDays));
  final startTime = DateTime.now().millisecondsSinceEpoch;
  var totalDeleted = 0;
  var batchesProcessed = 0;

  try {
    while (batchesProcessed < maxBatches) {
      final snapshot = await db
          .collectionGroup('instances')
          .where('status', 'in', const ['completed', 'skipped'])
          .where('updatedAt', '<=', cutoffDate)
          .limit(batchLimit)
          .get();

      if (snapshot.empty) {
        break;
      }

      final docsToDelete = snapshot.docs.where((doc) {
        final data = doc.data();
        if (data == null) return true;
        return data['status'] != 'pending';
      }).toList();

      if (docsToDelete.isEmpty) {
        break;
      }

      final batch = db.batch();
      for (final doc in docsToDelete) {
        batch.delete(doc.ref);
      }

      await batch.commit();
      totalDeleted += docsToDelete.length;
      batchesProcessed++;

      if (snapshot.size < batchLimit) {
        break;
      }
    }

    final durationMs = DateTime.now().millisecondsSinceEpoch - startTime;
    logInfo(
      'History cleanup completed successfully: deleted $totalDeleted documents across $batchesProcessed batches in ${durationMs}ms',
    );

    return HistoryCleanupResult(
      success: true,
      totalDeleted: totalDeleted,
      batchesProcessed: batchesProcessed,
      durationMs: durationMs,
    );
  } catch (error) {
    final durationMs = DateTime.now().millisecondsSinceEpoch - startTime;
    logError(
      'Error during history cleanup processing after ${durationMs}ms:',
      error,
    );
    rethrow;
  }
}
