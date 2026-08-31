import * as admin from "firebase-admin";
import { processHistoryCleanup } from "./cleanup_history";

describe("processHistoryCleanup", () => {
  it("deletes expired history documents and commits in batches", async () => {
    const mockRef1 = { path: "users/u1/history/d1" };
    const mockRef2 = { path: "users/u2/history/d2" };
    const mockDocs = [
      { id: "d1", ref: mockRef1 },
      { id: "d2", ref: mockRef2 },
    ];

    const mockDelete = jest.fn();
    const mockCommit = jest.fn().mockResolvedValue([]);
    const mockBatch = jest.fn(() => ({
      delete: mockDelete,
      commit: mockCommit,
    }));

    const mockGet = jest.fn().mockResolvedValue({
      empty: false,
      size: 2,
      docs: mockDocs,
    });

    const mockQuery = {
      where: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: mockGet,
    };

    const mockDb = {
      collectionGroup: jest.fn().mockReturnValue(mockQuery),
      batch: mockBatch,
    } as unknown as admin.firestore.Firestore;

    const testNow = admin.firestore.Timestamp.fromDate(new Date("2026-08-31T00:00:00Z"));
    const result = await processHistoryCleanup(mockDb, testNow, 500);

    expect(mockDb.collectionGroup).toHaveBeenCalledWith("history");
    expect(mockQuery.where).toHaveBeenCalledWith("expiresAt", "<=", testNow);
    expect(mockQuery.limit).toHaveBeenCalledWith(500);
    expect(mockDelete).toHaveBeenCalledWith(mockRef1);
    expect(mockDelete).toHaveBeenCalledWith(mockRef2);
    expect(mockCommit).toHaveBeenCalledTimes(1);
    expect(result.success).toBe(true);
    expect(result.totalDeleted).toBe(2);
    expect(result.batchesProcessed).toBe(1);
    expect(result.durationMs).toBeGreaterThanOrEqual(0);
  });

  it("handles pagination / multi-batch deletion when expired documents exceed single batch limit", async () => {
    const firstBatchDocs = Array.from({ length: 500 }, (_, i) => ({
      id: `doc_b1_${i}`,
      ref: { path: `users/u1/history/doc_b1_${i}` },
    }));
    const secondBatchDocs = Array.from({ length: 250 }, (_, i) => ({
      id: `doc_b2_${i}`,
      ref: { path: `users/u2/history/doc_b2_${i}` },
    }));

    const mockDelete = jest.fn();
    const mockCommit = jest.fn().mockResolvedValue([]);
    const mockBatch = jest.fn(() => ({
      delete: mockDelete,
      commit: mockCommit,
    }));

    const mockGet = jest
      .fn()
      .mockResolvedValueOnce({
        empty: false,
        size: 500,
        docs: firstBatchDocs,
      })
      .mockResolvedValueOnce({
        empty: false,
        size: 250,
        docs: secondBatchDocs,
      });

    const mockQuery = {
      where: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: mockGet,
    };

    const mockDb = {
      collectionGroup: jest.fn().mockReturnValue(mockQuery),
      batch: mockBatch,
    } as unknown as admin.firestore.Firestore;

    const testNow = admin.firestore.Timestamp.now();
    const result = await processHistoryCleanup(mockDb, testNow, 500);

    expect(mockGet).toHaveBeenCalledTimes(2);
    expect(mockBatch).toHaveBeenCalledTimes(2);
    expect(mockDelete).toHaveBeenCalledTimes(750);
    expect(mockCommit).toHaveBeenCalledTimes(2);
    expect(result.success).toBe(true);
    expect(result.totalDeleted).toBe(750);
    expect(result.batchesProcessed).toBe(2);
  });

  it("handles no-op scenario when no documents have expired", async () => {
    const mockDelete = jest.fn();
    const mockCommit = jest.fn();
    const mockBatch = jest.fn(() => ({
      delete: mockDelete,
      commit: mockCommit,
    }));

    const mockGet = jest.fn().mockResolvedValue({
      empty: true,
      size: 0,
      docs: [],
    });

    const mockQuery = {
      where: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: mockGet,
    };

    const mockDb = {
      collectionGroup: jest.fn().mockReturnValue(mockQuery),
      batch: mockBatch,
    } as unknown as admin.firestore.Firestore;

    const testNow = admin.firestore.Timestamp.now();
    const result = await processHistoryCleanup(mockDb, testNow, 500);

    expect(mockGet).toHaveBeenCalledTimes(1);
    expect(mockBatch).not.toHaveBeenCalled();
    expect(mockDelete).not.toHaveBeenCalled();
    expect(mockCommit).not.toHaveBeenCalled();
    expect(result.success).toBe(true);
    expect(result.totalDeleted).toBe(0);
    expect(result.batchesProcessed).toBe(0);
  });

  it("respects maxBatches limit to prevent unbounded loops", async () => {
    const fullBatchDocs = Array.from({ length: 100 }, (_, i) => ({
      id: `doc_${i}`,
      ref: { path: `users/u1/history/doc_${i}` },
    }));

    const mockDelete = jest.fn();
    const mockCommit = jest.fn().mockResolvedValue([]);
    const mockBatch = jest.fn(() => ({
      delete: mockDelete,
      commit: mockCommit,
    }));

    const mockGet = jest.fn().mockResolvedValue({
      empty: false,
      size: 100,
      docs: fullBatchDocs,
    });

    const mockQuery = {
      where: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: mockGet,
    };

    const mockDb = {
      collectionGroup: jest.fn().mockReturnValue(mockQuery),
      batch: mockBatch,
    } as unknown as admin.firestore.Firestore;

    const testNow = admin.firestore.Timestamp.now();
    // Set maxBatches to 3
    const result = await processHistoryCleanup(mockDb, testNow, 100, 3);

    expect(mockGet).toHaveBeenCalledTimes(3);
    expect(mockCommit).toHaveBeenCalledTimes(3);
    expect(result.success).toBe(true);
    expect(result.totalDeleted).toBe(300);
    expect(result.batchesProcessed).toBe(3);
  });

  it("handles and logs error when batch commit fails", async () => {
    const mockRef = { path: "users/u1/history/d1" };
    const mockDocs = [{ id: "d1", ref: mockRef }];

    const commitError = new Error("Firestore batch commit failed due to connection error");
    const mockDelete = jest.fn();
    const mockCommit = jest.fn().mockRejectedValue(commitError);
    const mockBatch = jest.fn(() => ({
      delete: mockDelete,
      commit: mockCommit,
    }));

    const mockGet = jest.fn().mockResolvedValue({
      empty: false,
      size: 1,
      docs: mockDocs,
    });

    const mockQuery = {
      where: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: mockGet,
    };

    const mockDb = {
      collectionGroup: jest.fn().mockReturnValue(mockQuery),
      batch: mockBatch,
    } as unknown as admin.firestore.Firestore;

    const testNow = admin.firestore.Timestamp.now();
    await expect(processHistoryCleanup(mockDb, testNow, 500)).rejects.toThrow(
      "Firestore batch commit failed due to connection error"
    );
  });
});
