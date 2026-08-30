import {
  validateTaskEvent,
  processExternalTaskEvent,
  authenticateTaskEventRequest,
  ExternalTaskEvent,
} from "./task_events";

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

describe("authenticateTaskEventRequest", () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it("authenticates via valid service secret header (x-service-secret)", async () => {
    process.env.TASK_HUB_SECRET = "super_secret_token";
    const headers = { "x-service-secret": "super_secret_token" };

    const result = await authenticateTaskEventRequest(headers, "user_123");
    expect(result.authenticated).toBe(true);
  });

  it("authenticates via valid service secret header (x-api-key)", async () => {
    process.env.SERVICE_SECRET = "api_key_secret";
    const headers = { "x-api-key": "api_key_secret" };

    const result = await authenticateTaskEventRequest(headers, "user_123");
    expect(result.authenticated).toBe(true);
  });

  it("authenticates via valid Bearer service secret", async () => {
    process.env.TASK_HUB_SECRET = "bearer_secret";
    const headers = { authorization: "Bearer bearer_secret" };

    const result = await authenticateTaskEventRequest(headers, "user_123");
    expect(result.authenticated).toBe(true);
  });

  it("authenticates via valid Firebase ID token matching target userId", async () => {
    const mockAuth = {
      verifyIdToken: jest.fn().mockResolvedValue({ uid: "user_123" }),
    } as unknown as import("firebase-admin").auth.Auth;

    const headers = { authorization: "Bearer valid_id_token" };
    const result = await authenticateTaskEventRequest(headers, "user_123", mockAuth);
    expect(result.authenticated).toBe(true);
  });

  it("authenticates admin Firebase ID token even if uid differs", async () => {
    const mockAuth = {
      verifyIdToken: jest.fn().mockResolvedValue({ uid: "admin_user", admin: true }),
    } as unknown as import("firebase-admin").auth.Auth;

    const headers = { authorization: "Bearer admin_id_token" };
    const result = await authenticateTaskEventRequest(headers, "user_123", mockAuth);
    expect(result.authenticated).toBe(true);
  });

  it("rejects token when uid does not match target userId and not admin (403)", async () => {
    const mockAuth = {
      verifyIdToken: jest.fn().mockResolvedValue({ uid: "other_user" }),
    } as unknown as import("firebase-admin").auth.Auth;

    const headers = { authorization: "Bearer foreign_token" };
    const result = await authenticateTaskEventRequest(headers, "user_123", mockAuth);
    expect(result.authenticated).toBe(false);
    expect(result.status).toBe(403);
    expect(result.error).toContain("Forbidden");
  });

  it("rejects invalid/expired Firebase ID token (401)", async () => {
    const mockAuth = {
      verifyIdToken: jest.fn().mockRejectedValue(new Error("Token expired")),
    } as unknown as import("firebase-admin").auth.Auth;

    const headers = { authorization: "Bearer expired_token" };
    const result = await authenticateTaskEventRequest(headers, "user_123", mockAuth);
    expect(result.authenticated).toBe(false);
    expect(result.status).toBe(401);
    expect(result.error).toContain("Invalid or expired");
  });

  it("rejects missing authentication credentials (401)", async () => {
    const headers = {};
    const result = await authenticateTaskEventRequest(headers, "user_123");
    expect(result.authenticated).toBe(false);
    expect(result.status).toBe(401);
    expect(result.error).toContain("Missing or invalid authentication");
  });
});

describe("processExternalTaskEvent", () => {
  it("updates an existing TaskInstance when marked completed and synchronizes completedByUserIds", async () => {
    const mockUpdate = jest.fn().mockResolvedValue(undefined);
    const mockDoc = {
      id: "inst_existing_123",
      ref: { update: mockUpdate },
      data: () => ({
        scheduledDate: "2026-08-30",
        status: "pending",
        completedByUserIds: ["other_user"],
      }),
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
        completedByUserIds: ["other_user", "user_123"],
      })
    );
  });

  it("updates an existing TaskInstance when marked uncompleted and removes userId from completedByUserIds", async () => {
    const mockUpdate = jest.fn().mockResolvedValue(undefined);
    const mockDoc = {
      id: "inst_existing_123",
      ref: { update: mockUpdate },
      data: () => ({
        scheduledDate: "2026-08-30",
        status: "completed",
        completedByUserId: "user_123",
        completedByUserIds: ["user_123", "family_member_2"],
      }),
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
      action: "uncompleted",
    };

    const result = await processExternalTaskEvent(mockDb, event);
    expect(result.success).toBe(true);
    expect(result.instanceId).toBe("inst_existing_123");
    expect(result.actionApplied).toBe("uncompleted");
    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        status: "pending",
        completedAt: null,
        completedByUserId: null,
        completedByUserIds: ["family_member_2"],
      })
    );
  });

  it("updates an existing TaskInstance when marked dismissed", async () => {
    const mockUpdate = jest.fn().mockResolvedValue(undefined);
    const mockDoc = {
      id: "inst_existing_123",
      ref: { update: mockUpdate },
      data: () => ({
        scheduledDate: "2026-08-30",
        status: "pending",
      }),
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
      action: "dismissed",
    };

    const result = await processExternalTaskEvent(mockDb, event);
    expect(result.success).toBe(true);
    expect(result.instanceId).toBe("inst_existing_123");
    expect(result.actionApplied).toBe("dismissed");
    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        status: "dismissed",
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
        completedByUserIds: ["user_123"],
        integrationBinding: expect.objectContaining({
          providerId: "twelve_stars",
          externalId: "rosary",
        }),
      })
    );
  });
});
