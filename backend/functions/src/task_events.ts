import * as admin from "firebase-admin";

export interface ExternalTaskEvent {
  userId: string;
  providerId: string;
  entityType: string;
  externalId: string;
  date: string; // YYYY-MM-DD format (CivilDay)
  action: "completed" | "uncompleted" | "dismissed";
  timestamp?: string;
  metadata?: Record<string, unknown>;
}

export interface TaskEventResult {
  success: boolean;
  instanceId?: string;
  actionApplied: string;
  createdNewInstance?: boolean;
  message?: string;
}

/**
 * Validates the structure of an incoming ExternalTaskEvent.
 */
export function validateTaskEvent(payload: unknown): { valid: boolean; error?: string; event?: ExternalTaskEvent } {
  if (!payload || typeof payload !== "object") {
    return { valid: false, error: "Event payload must be a non-null object" };
  }

  const p = payload as Record<string, unknown>;
  const requiredFields = ["userId", "providerId", "entityType", "externalId", "date", "action"];
  for (const field of requiredFields) {
    if (typeof p[field] !== "string" || !p[field]) {
      return { valid: false, error: `Missing or invalid required string field: ${field}` };
    }
  }

  const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
  if (!dateRegex.test(p.date as string)) {
    return { valid: false, error: "Field 'date' must match YYYY-MM-DD format" };
  }

  const validActions = ["completed", "uncompleted", "dismissed"];
  if (!validActions.includes(p.action as string)) {
    return { valid: false, error: `Invalid action '${p.action}'. Must be one of: ${validActions.join(", ")}` };
  }

  return {
    valid: true,
    event: {
      userId: p.userId as string,
      providerId: p.providerId as string,
      entityType: p.entityType as string,
      externalId: p.externalId as string,
      date: p.date as string,
      action: p.action as "completed" | "uncompleted" | "dismissed",
      timestamp: typeof p.timestamp === "string" ? p.timestamp : new Date().toISOString(),
      metadata: typeof p.metadata === "object" && p.metadata !== null ? (p.metadata as Record<string, unknown>) : undefined,
    },
  };
}

/**
 * Processes an incoming ExternalTaskEvent and updates/creates the corresponding TaskInstance in Firestore.
 */
export async function processExternalTaskEvent(
  db: admin.firestore.Firestore,
  event: ExternalTaskEvent
): Promise<TaskEventResult> {
  const instancesRef = db.collection("users").doc(event.userId).collection("instances");

  // Query instances matching the date and provider/external ID binding
  const querySnap = await instancesRef
    .where("scheduledDate", "==", event.date)
    .where("integrationBinding.providerId", "==", event.providerId)
    .where("integrationBinding.externalId", "==", event.externalId)
    .limit(1)
    .get();

  const now = new Date();
  const nowIso = now.toISOString();

  let targetStatus = "pending";
  let completedAt: string | null = null;
  let completedByUserId: string | null = null;

  if (event.action === "completed") {
    targetStatus = "completed";
    completedAt = event.timestamp || nowIso;
    completedByUserId = event.userId;
  } else if (event.action === "dismissed") {
    targetStatus = "dismissed";
  } else if (event.action === "uncompleted") {
    targetStatus = "pending";
    completedAt = null;
    completedByUserId = null;
  }

  if (!querySnap.empty) {
    // Update existing instance
    const doc = querySnap.docs[0];
    await doc.ref.update({
      status: targetStatus,
      completedAt: completedAt,
      completedByUserId: completedByUserId,
      updatedAt: nowIso,
      lastModifiedByUserId: event.userId,
    });

    return {
      success: true,
      instanceId: doc.id,
      actionApplied: event.action,
      createdNewInstance: false,
    };
  }

  // If no instance exists for that day, check if a parent TaskSchedule template exists
  const schedulesRef = db.collection("users").doc(event.userId).collection("tasks");
  const scheduleSnap = await schedulesRef
    .where("integrationBinding.providerId", "==", event.providerId)
    .where("integrationBinding.externalId", "==", event.externalId)
    .limit(1)
    .get();

  let scheduleId = `SCHED-${event.providerId}-${event.externalId}`;
  let title = `${event.providerId}: ${event.externalId}`;
  let description = `Auto-tracked from ${event.providerId}`;

  if (!scheduleSnap.empty) {
    const sDoc = scheduleSnap.docs[0];
    scheduleId = sDoc.id;
    const sData = sDoc.data();
    if (sData.title) title = sData.title;
    if (sData.description) description = sData.description;
  }

  // Create a Just-in-Time TaskInstance document
  const newInstanceRef = instancesRef.doc();
  const newInstance = {
    id: newInstanceRef.id,
    scheduleId: scheduleId,
    ruleId: "RULE-EXT-SYNC",
    title: title,
    description: description,
    scheduledDate: event.date,
    startRelativeTime: { minutes: 0 },
    dueRelativeTime: { minutes: 1439 },
    isFamily: false,
    status: targetStatus,
    completedAt: completedAt,
    completedByUserId: completedByUserId,
    completedByUserIds: completedByUserId ? [completedByUserId] : [],
    integrationBinding: {
      providerId: event.providerId,
      entityType: event.entityType,
      externalId: event.externalId,
      bidirectional: true,
    },
    updatedAt: nowIso,
    createdAt: nowIso,
    lastModifiedByUserId: event.userId,
  };

  await newInstanceRef.set(newInstance);

  return {
    success: true,
    instanceId: newInstanceRef.id,
    actionApplied: event.action,
    createdNewInstance: true,
    message: `Created and applied ${event.action} to new TaskInstance`,
  };
}
