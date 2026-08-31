import * as admin from "firebase-admin";
import {
  authenticateUserRequest,
  deleteUserAccountData,
  handleDeleteUserAccount,
} from "./account_deletion";

describe("authenticateUserRequest", () => {
  it("authenticates a valid Bearer ID token", async () => {
    const mockAuth = {
      verifyIdToken: jest.fn().mockResolvedValue({
        uid: "user_abc_123",
        email: "tester@example.com",
      }),
    } as unknown as admin.auth.Auth;

    const headers = { authorization: "Bearer valid_id_token" };
    const result = await authenticateUserRequest(headers, mockAuth);

    expect(result.authenticated).toBe(true);
    expect(result.user?.uid).toBe("user_abc_123");
    expect(result.user?.email).toBe("tester@example.com");
  });

  it("handles case-insensitive Authorization header", async () => {
    const mockAuth = {
      verifyIdToken: jest.fn().mockResolvedValue({
        uid: "user_abc_123",
        email: "tester@example.com",
      }),
    } as unknown as admin.auth.Auth;

    const headers = { Authorization: "Bearer valid_id_token" };
    const result = await authenticateUserRequest(headers, mockAuth);

    expect(result.authenticated).toBe(true);
    expect(result.user?.uid).toBe("user_abc_123");
  });

  it("rejects missing Authorization header with 401", async () => {
    const headers = {};
    const result = await authenticateUserRequest(headers);

    expect(result.authenticated).toBe(false);
    expect(result.status).toBe(401);
    expect(result.error).toContain("Missing or invalid Authorization header");
  });

  it("rejects malformed Authorization header with 401", async () => {
    const headers = { authorization: "Basic some_basic_auth_string" };
    const result = await authenticateUserRequest(headers);

    expect(result.authenticated).toBe(false);
    expect(result.status).toBe(401);
  });

  it("rejects invalid or expired token with 401", async () => {
    const mockAuth = {
      verifyIdToken: jest.fn().mockRejectedValue(new Error("Token expired")),
    } as unknown as admin.auth.Auth;

    const headers = { authorization: "Bearer expired_token" };
    const result = await authenticateUserRequest(headers, mockAuth);

    expect(result.authenticated).toBe(false);
    expect(result.status).toBe(401);
    expect(result.error).toContain("Invalid or expired authentication token");
  });
});

describe("deleteUserAccountData", () => {
  it("deletes sole family member, purging family, invites, user data, and auth profile", async () => {
    const mockUserDoc = {
      exists: true,
      data: () => ({
        familyId: "fam_123",
        email: "soleuser@example.com",
      }),
    };

    const mockFamilyDoc = {
      exists: true,
      data: () => ({
        name: "Test Family",
        members: {
          user_sole: { role: "parent", email: "soleuser@example.com" },
        },
      }),
    };

    const mockUserRef = { id: "user_sole" };
    const mockFamilyRef = { id: "fam_123" };

    const mockBatchDelete = jest.fn();
    const mockBatchCommit = jest.fn().mockResolvedValue(undefined);
    const mockBatch = {
      delete: mockBatchDelete,
      commit: mockBatchCommit,
    };

    const mockInviteDoc1 = { id: "inv_1", ref: { id: "inv_1" } };
    const mockInviteDoc2 = { id: "inv_2", ref: { id: "inv_2" } };

    const mockRecursiveDelete = jest.fn().mockResolvedValue(undefined);

    const mockDb = {
      collection: jest.fn((colName: string) => {
        if (colName === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              ...mockUserRef,
              get: jest.fn().mockResolvedValue(mockUserDoc),
            }),
          };
        }
        if (colName === "families") {
          return {
            doc: jest.fn().mockReturnValue({
              ...mockFamilyRef,
              get: jest.fn().mockResolvedValue(mockFamilyDoc),
            }),
          };
        }
        if (colName === "invites") {
          return {
            where: jest.fn((field: string) => ({
              get: jest.fn().mockResolvedValue({
                docs: field === "toEmail" ? [mockInviteDoc1] : [mockInviteDoc2],
              }),
            })),
          };
        }
        return {};
      }),
      batch: jest.fn().mockReturnValue(mockBatch),
      recursiveDelete: mockRecursiveDelete,
    } as unknown as admin.firestore.Firestore;

    const mockAuth = {
      deleteUser: jest.fn().mockResolvedValue(undefined),
    } as unknown as admin.auth.Auth;

    const result = await deleteUserAccountData(
      mockDb,
      mockAuth,
      "user_sole",
      "soleuser@example.com"
    );

    expect(result.success).toBe(true);
    expect(result.userId).toBe("user_sole");
    // Family was sole member -> family document recursively deleted
    expect(mockRecursiveDelete).toHaveBeenCalledWith(expect.objectContaining({ id: "fam_123" }));
    // Invites deleted
    expect(mockBatchDelete).toHaveBeenCalledTimes(2);
    expect(mockBatchCommit).toHaveBeenCalled();
    // User doc recursively deleted
    expect(mockRecursiveDelete).toHaveBeenCalledWith(expect.objectContaining({ id: "user_sole" }));
    // Auth deleted
    expect(mockAuth.deleteUser).toHaveBeenCalledWith("user_sole");
  });

  it("removes user from multi-member family without deleting entire family", async () => {
    const mockUserDoc = {
      exists: true,
      data: () => ({
        familyId: "fam_multi",
        email: "member1@example.com",
      }),
    };

    const mockFamilyDoc = {
      exists: true,
      data: () => ({
        name: "Multi Member Family",
        members: {
          user_multi_1: { role: "parent" },
          user_multi_2: { role: "parent" },
        },
      }),
    };

    const mockFamilyUpdate = jest.fn().mockResolvedValue(undefined);
    const mockUserRef = { id: "user_multi_1" };
    const mockFamilyRef = {
      id: "fam_multi",
      update: mockFamilyUpdate,
    };

    const mockBatch = {
      delete: jest.fn(),
      commit: jest.fn().mockResolvedValue(undefined),
    };

    const mockRecursiveDelete = jest.fn().mockResolvedValue(undefined);

    const mockDb = {
      collection: jest.fn((colName: string) => {
        if (colName === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              ...mockUserRef,
              get: jest.fn().mockResolvedValue(mockUserDoc),
            }),
          };
        }
        if (colName === "families") {
          return {
            doc: jest.fn().mockReturnValue({
              ...mockFamilyRef,
              get: jest.fn().mockResolvedValue(mockFamilyDoc),
            }),
          };
        }
        if (colName === "invites") {
          return {
            where: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({ docs: [] }),
            }),
          };
        }
        return {};
      }),
      batch: jest.fn().mockReturnValue(mockBatch),
      recursiveDelete: mockRecursiveDelete,
    } as unknown as admin.firestore.Firestore;

    const mockAuth = {
      deleteUser: jest.fn().mockResolvedValue(undefined),
    } as unknown as admin.auth.Auth;

    const result = await deleteUserAccountData(
      mockDb,
      mockAuth,
      "user_multi_1",
      "member1@example.com"
    );

    expect(result.success).toBe(true);
    expect(mockFamilyUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        "members.user_multi_1": admin.firestore.FieldValue.delete(),
      })
    );
    expect(mockRecursiveDelete).toHaveBeenCalledWith(expect.objectContaining({ id: "user_multi_1" }));
    expect(mockAuth.deleteUser).toHaveBeenCalledWith("user_multi_1");
  });

  it("handles user without family association gracefully", async () => {
    const mockUserDoc = {
      exists: true,
      data: () => ({
        email: "loner@example.com",
      }),
    };

    const mockRecursiveDelete = jest.fn().mockResolvedValue(undefined);
    const mockBatch = {
      delete: jest.fn(),
      commit: jest.fn().mockResolvedValue(undefined),
    };

    const mockDb = {
      collection: jest.fn((colName: string) => {
        if (colName === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              id: "user_loner",
              get: jest.fn().mockResolvedValue(mockUserDoc),
            }),
          };
        }
        if (colName === "invites") {
          return {
            where: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({ docs: [] }),
            }),
          };
        }
        return {};
      }),
      batch: jest.fn().mockReturnValue(mockBatch),
      recursiveDelete: mockRecursiveDelete,
    } as unknown as admin.firestore.Firestore;

    const mockAuth = {
      deleteUser: jest.fn().mockResolvedValue(undefined),
    } as unknown as admin.auth.Auth;

    const result = await deleteUserAccountData(mockDb, mockAuth, "user_loner");
    expect(result.success).toBe(true);
    expect(mockRecursiveDelete).toHaveBeenCalledWith(expect.objectContaining({ id: "user_loner" }));
    expect(mockAuth.deleteUser).toHaveBeenCalledWith("user_loner");
  });

  it("ignores auth/user-not-found error if Auth user is already deleted", async () => {
    const mockUserDoc = {
      exists: false,
      data: () => undefined,
    };

    const mockRecursiveDelete = jest.fn().mockResolvedValue(undefined);
    const mockDb = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({
          id: "user_missing",
          get: jest.fn().mockResolvedValue(mockUserDoc),
        }),
      }),
      batch: jest.fn().mockReturnValue({ commit: jest.fn() }),
      recursiveDelete: mockRecursiveDelete,
    } as unknown as admin.firestore.Firestore;

    const notFoundError = new Error("User not found");
    (notFoundError as { code?: string }).code = "auth/user-not-found";

    const mockAuth = {
      deleteUser: jest.fn().mockRejectedValue(notFoundError),
    } as unknown as admin.auth.Auth;

    const result = await deleteUserAccountData(mockDb, mockAuth, "user_missing");
    expect(result.success).toBe(true);
  });
});

describe("handleDeleteUserAccount", () => {
  it("rejects non-POST/DELETE requests with 405 Method Not Allowed", async () => {
    const req = {
      method: "GET",
      headers: {},
    };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };

    await handleDeleteUserAccount(req, res);

    expect(res.status).toHaveBeenCalledWith(405);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.stringContaining("Method Not Allowed") })
    );
  });

  it("rejects unauthenticated requests with 401 Unauthorized", async () => {
    const req = {
      method: "POST",
      headers: {},
    };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };

    await handleDeleteUserAccount(req, res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false })
    );
  });

  it("successfully processes valid POST request with 200 OK", async () => {
    const mockAuth = {
      verifyIdToken: jest.fn().mockResolvedValue({
        uid: "user_delete_me",
        email: "delete_me@example.com",
      }),
      deleteUser: jest.fn().mockResolvedValue(undefined),
    } as unknown as admin.auth.Auth;

    const mockUserDoc = { exists: false, data: () => undefined };
    const mockDb = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({
          id: "user_delete_me",
          get: jest.fn().mockResolvedValue(mockUserDoc),
        }),
        where: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({ docs: [] }),
        }),
      }),
      batch: jest.fn().mockReturnValue({ commit: jest.fn() }),
      recursiveDelete: jest.fn().mockResolvedValue(undefined),
    } as unknown as admin.firestore.Firestore;

    const req = {
      method: "POST",
      headers: { authorization: "Bearer valid_user_token" },
    };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };

    await handleDeleteUserAccount(req, res, mockDb, mockAuth);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        userId: "user_delete_me",
      })
    );
  });

  it("returns 500 when backend deletion fails", async () => {
    const mockAuth = {
      verifyIdToken: jest.fn().mockResolvedValue({
        uid: "user_fail",
        email: "fail@example.com",
      }),
      deleteUser: jest.fn().mockRejectedValue(new Error("Database write lock error")),
    } as unknown as admin.auth.Auth;

    const mockDb = {
      collection: jest.fn().mockReturnValue({
        doc: jest.fn().mockReturnValue({
          id: "user_fail",
          get: jest.fn().mockResolvedValue({ exists: false }),
        }),
        where: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({ docs: [] }),
        }),
      }),
      batch: jest.fn().mockReturnValue({ commit: jest.fn() }),
      recursiveDelete: jest.fn().mockResolvedValue(undefined),
    } as unknown as admin.firestore.Firestore;

    const req = {
      method: "POST",
      headers: { authorization: "Bearer valid_user_token" },
    };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };

    await handleDeleteUserAccount(req, res, mockDb, mockAuth);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: "Database write lock error",
      })
    );
  });
});
