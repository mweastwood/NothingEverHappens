import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

export interface HistoryCleanupResult {
  success: boolean;
  totalDeleted: number;
  batchesProcessed: number;
  durationMs: number;
}

/**
 * Core handler to process batch deletion of expired task history documents across Firestore.
 * Queries db.collectionGroup("history") for documents where expiresAt <= now.
 *
 * @param db - Firestore database instance.
 * @param now - Reference timestamp threshold for expiration (defaults to admin.firestore.Timestamp.now()).
 * @param batchLimit - Number of documents to delete per batch (max 500 per Firebase guidelines).
 * @param maxBatches - Safe limit on number of batch iterations per execution to prevent timeouts.
 */
export async function processHistoryCleanup(
  db: admin.firestore.Firestore,
  now: admin.firestore.Timestamp = admin.firestore.Timestamp.now(),
  batchLimit: number = 500,
  maxBatches: number = 20
): Promise<HistoryCleanupResult> {
  const startTime = Date.now();
  let totalDeleted = 0;
  let batchesProcessed = 0;

  try {
    while (batchesProcessed < maxBatches) {
      const snapshot = await db
        .collectionGroup("history")
        .where("expiresAt", "<=", now)
        .limit(batchLimit)
        .get();

      if (snapshot.empty) {
        break;
      }

      const batch = db.batch();
      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
      }

      await batch.commit();
      totalDeleted += snapshot.size;
      batchesProcessed++;

      if (snapshot.size < batchLimit) {
        break;
      }
    }

    const durationMs = Date.now() - startTime;
    logger.info(
      `History cleanup completed successfully: deleted ${totalDeleted} documents across ${batchesProcessed} batches in ${durationMs}ms`
    );

    return {
      success: true,
      totalDeleted,
      batchesProcessed,
      durationMs,
    };
  } catch (error) {
    const durationMs = Date.now() - startTime;
    logger.error("Error during history cleanup processing:", error);
    throw error;
  }
}
