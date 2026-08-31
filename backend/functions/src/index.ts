import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { validateTaskEvent, processExternalTaskEvent, authenticateTaskEventRequest } from "./task_events";
import { handleDeleteUserAccount } from "./account_deletion";

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

/**
 * HTTP endpoint for permanently deleting a user account and cascading all associated data.
 * POST /deleteUserAccount
 */
export const deleteUserAccount = onRequest(
  {
    cors: true,
    memory: "256MiB",
  },
  async (req, res) => {
    await handleDeleteUserAccount(req, res, db, auth);
  }
);


/**
 * HTTP endpoint for receiving external task events from satellite apps (PetalCount, TwelveStars, etc.).
 * POST /reportExternalTaskEvent
 */
export const reportExternalTaskEvent = onRequest(
  {
    cors: true,
    memory: "256MiB",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ success: false, error: "Method Not Allowed. Use POST." });
      return;
    }

    const validation = validateTaskEvent(req.body);
    if (!validation.valid || !validation.event) {
      logger.warn("Invalid external task event received:", req.body, validation.error);
      res.status(400).json({ success: false, error: validation.error });
      return;
    }

    const authResult = await authenticateTaskEventRequest(req.headers, validation.event.userId);
    if (!authResult.authenticated) {
      logger.warn(
        `Unauthorized external task event attempt for user ${validation.event.userId}: ${authResult.error}`
      );
      res.status(authResult.status || 401).json({ success: false, error: authResult.error });
      return;
    }

    try {
      const result = await processExternalTaskEvent(db, validation.event);
      logger.info(
        `Processed task event for user ${validation.event.userId}, provider ${validation.event.providerId}: ${validation.event.action}`
      );
      res.status(200).json(result);
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      logger.error("Error processing external task event:", error);
      res.status(500).json({ success: false, error: errorMessage });
    }
  }
);

/**
 * Health check / status endpoint for the Nothing Ever Happens Task Hub Functions.
 * GET /status
 */
export const status = onRequest(
  { cors: true, memory: "128MiB" },
  async (req, res) => {
    res.status(200).json({
      status: "ok",
      service: "Nothing Ever Happens Cloud Functions",
      version: "1.0.0",
      timestamp: new Date().toISOString(),
    });
  }
);
