import { validateTaskEvent, processExternalTaskEvent, ExternalTaskEvent } from "./task_events";

describe("validateTaskEvent", () => {
  it("validates a valid task event", () => {
    const payload = {
      userId: "user_123",
      providerId: "petal_count",
      entityType: "supplement",
      externalId: "preset_prenatal_morning",
      date: "2026-08-30",
      action: "completed",
    };

    const result = validateTaskEvent(payload);
    expect(result.valid).toBe(true);
    expect(result.event).toBeDefined();
    expect(result.event?.userId).toBe("user_123");
    expect(result.event?.action).toBe("completed");
  });

  it("rejects payload missing required fields", () => {
    const payload = {
      userId: "user_123",
      date: "2026-08-30",
    };

    const result = validateTaskEvent(payload);
    expect(result.valid).toBe(false);
    expect(result.error).toContain("Missing or invalid required string field");
  });

  it("rejects invalid date format", () => {
    const payload = {
      userId: "user_123",
      providerId: "twelve_stars",
      entityType: "prayer",
      externalId: "rosary",
      date: "30-08-2026",
      action: "completed",
    };

    const result = validateTaskEvent(payload);
    expect(result.valid).toBe(false);
    expect(result.error).toContain("YYYY-MM-DD");
  });

  it("rejects unknown action", () => {
    const payload = {
      userId: "user_123",
      providerId: "twelve_stars",
      entityType: "prayer",
      externalId: "rosary",
      date: "2026-08-30",
      action: "invalid_action",
    };

    const result = validateTaskEvent(payload);
    expect(result.valid).toBe(false);
    expect(result.error).toContain("Invalid action");
  });
});

describe("processExternalTaskEvent", () => {
  it("updates an existing TaskInstance when found", async () => {
    const mockUpdate = jest.fn().mockResolvedValue(undefined);
    const mockDoc = {
      id: "inst_existing_123",
      ref: { update: mockUpdate },
      data: () => ({ scheduledDate: "2026-08-30", status: "pending" }),
    };

    const mockGetInstances = jest.fn().mockResolvedValue({
      empty: false,
      docs: [mockDoc],
    });

    const mockInstancesQuery = {
      where: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: mockGetInstances,
    };

    const mockDb = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({
          collection: jest.fn().mockReturnValue(mockInstancesQuery),
        }),
      }),
    } as unknown as import("firebase-admin").firestore.Firestore;

    const event: ExternalTaskEvent = {
      userId: "user_123",
      providerId: "petal_count",
      entityType: "supplement",
      externalId: "preset_prenatal_morning",
      date: "2026-08-30",
      action: "completed",
    };

    const result = await processExternalTaskEvent(mockDb, event);
    expect(result.success).toBe(true);
    expect(result.instanceId).toBe("inst_existing_123");
    expect(result.createdNewInstance).toBe(false);
    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        status: "completed",
        completedByUserId: "user_123",
      })
    );
  });

  it("creates a new TaskInstance (JIT) when no existing instance matches", async () => {
    const mockSet = jest.fn().mockResolvedValue(undefined);
    const mockNewDocRef = {
      id: "inst_generated_999",
      set: mockSet,
    };

    const mockGetInstances = jest.fn().mockResolvedValue({
      empty: true,
      docs: [],
    });

    const mockGetSchedules = jest.fn().mockResolvedValue({
      empty: true,
      docs: [],
    });

    const mockCollection = jest.fn((colName: string) => {
      if (colName === "instances") {
        return {
          where: jest.fn().mockReturnThis(),
          limit: jest.fn().mockReturnThis(),
          get: mockGetInstances,
          doc: jest.fn().mockReturnValue(mockNewDocRef),
        };
      }
      return {
        where: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        get: mockGetSchedules,
      };
    });

    const mockDb = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({
          collection: mockCollection,
        }),
      }),
    } as unknown as import("firebase-admin").firestore.Firestore;

    const event: ExternalTaskEvent = {
      userId: "user_123",
      providerId: "twelve_stars",
      entityType: "prayer",
      externalId: "rosary",
      date: "2026-08-30",
      action: "completed",
    };

    const result = await processExternalTaskEvent(mockDb, event);
    expect(result.success).toBe(true);
    expect(result.instanceId).toBe("inst_generated_999");
    expect(result.createdNewInstance).toBe(true);
    expect(mockSet).toHaveBeenCalledWith(
      expect.objectContaining({
        scheduledDate: "2026-08-30",
        status: "completed",
        integrationBinding: expect.objectContaining({
          providerId: "twelve_stars",
          externalId: "rosary",
        }),
      })
    );
  });
});
