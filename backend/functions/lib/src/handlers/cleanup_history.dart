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

/// Core handler to process batch deletion of expired task history documents across Firestore.
/// Queries db.collectionGroup("history") for documents where expiresAt <= now.
///
/// [db]: Firestore database instance.
/// [now]: Reference timestamp threshold for expiration.
/// [batchLimit]: Number of documents to delete per batch (max 500 per Firebase guidelines).
/// [maxBatches]: Safe limit on number of batch iterations per execution to prevent timeouts.
Future<HistoryCleanupResult> processHistoryCleanup(
  FirestoreDatabase db, [
  dynamic now,
  int batchLimit = 500,
  int maxBatches = 20,
]) async {
  final threshold = now ?? DateTime.now().toUtc();
  final startTime = DateTime.now().millisecondsSinceEpoch;
  var totalDeleted = 0;
  var batchesProcessed = 0;

  try {
    while (batchesProcessed < maxBatches) {
      final snapshot = await db
          .collectionGroup('history')
          .where('expiresAt', '<=', threshold)
          .limit(batchLimit)
          .get();

      if (snapshot.empty) {
        break;
      }

      final batch = db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.ref);
      }

      await batch.commit();
      totalDeleted += snapshot.size;
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
