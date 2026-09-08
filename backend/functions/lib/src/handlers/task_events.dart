import '../interop/firebase_admin.dart';
import '../interop/firebase_functions.dart';
import '../interop/node_interop.dart';
import '../models/civil_day.dart';
import '../models/task_event.dart';

/// Validates the structure of an incoming ExternalTaskEvent payload.
TaskEventValidation validateTaskEvent(dynamic payload) {
  if (payload == null || payload is! Map) {
    return const TaskEventValidation(
      valid: false,
      error: 'Event payload must be a non-null object',
    );
  }

  final p = Map<String, dynamic>.from(payload);
  const requiredFields = [
    'userId',
    'providerId',
    'entityType',
    'externalId',
    'date',
    'action',
  ];

  for (final field in requiredFields) {
    final val = p[field];
    if (val is! String || val.isEmpty) {
      return TaskEventValidation(
        valid: false,
        error: 'Missing or invalid required string field: $field',
      );
    }
  }

  final dateStr = p['date'] as String;
  if (!CivilDay.isValid(dateStr)) {
    return const TaskEventValidation(
      valid: false,
      error: "Field 'date' must match YYYY-MM-DD format",
    );
  }

  const validActions = ['completed', 'uncompleted', 'dismissed'];
  final action = p['action'] as String;
  if (!validActions.contains(action)) {
    return TaskEventValidation(
      valid: false,
      error:
          "Invalid action '$action'. Must be one of: ${validActions.join(', ')}",
    );
  }

  return TaskEventValidation(
    valid: true,
    event: ExternalTaskEvent(
      userId: p['userId'] as String,
      providerId: p['providerId'] as String,
      entityType: p['entityType'] as String,
      externalId: p['externalId'] as String,
      date: dateStr,
      action: action,
      timestamp: p['timestamp'] is String
          ? p['timestamp'] as String
          : DateTime.now().toUtc().toIso8601String(),
      metadata: p['metadata'] is Map
          ? Map<String, dynamic>.from(p['metadata'] as Map)
          : null,
    ),
  );
}

/// Authenticates an incoming request for reporting task events.
/// Accepts either:
/// 1. A valid Firebase Auth ID token matching the event userId (or with admin claims).
/// 2. A valid service secret matching TASK_HUB_SECRET or SERVICE_SECRET environment variable.
Future<TaskAuthValidationResult> authenticateTaskEventRequest(
  Map<String, dynamic> headers,
  String targetUserId, {
  AuthService? auth,
  String? envSecret,
}) async {
  final authHeaderRaw = headers['authorization'] ?? headers['Authorization'];
  final authHeader = authHeaderRaw is List
      ? (authHeaderRaw.isNotEmpty ? authHeaderRaw.first.toString() : null)
      : authHeaderRaw?.toString();

  final serviceKeyRaw = headers['x-service-secret'] ?? headers['x-api-key'];
  final serviceKey = serviceKeyRaw is List
      ? (serviceKeyRaw.isNotEmpty ? serviceKeyRaw.first.toString() : null)
      : serviceKeyRaw?.toString();

  final secret =
      envSecret ?? getEnv('TASK_HUB_SECRET') ?? getEnv('SERVICE_SECRET');

  // 1. Check Service Secret Header or Bearer secret
  if (secret != null &&
      secret.isNotEmpty &&
      (serviceKey == secret || authHeader == 'Bearer $secret')) {
    return const TaskAuthValidationResult(authenticated: true);
  }

  // 2. Check Firebase ID Token in Bearer header
  if (authHeader != null && authHeader.startsWith('Bearer ')) {
    final idToken = authHeader.substring(7).trim();
    if (idToken.isNotEmpty) {
      try {
        final firebaseAuth = auth ?? getFirebaseAdminAuth();
        final decodedToken = await firebaseAuth.verifyIdToken(idToken);
        if (decodedToken.uid == targetUserId || decodedToken.admin == true) {
          return const TaskAuthValidationResult(authenticated: true);
        }
        return const TaskAuthValidationResult(
          authenticated: false,
          status: 403,
          error: 'Forbidden: Authenticated user does not match target userId.',
        );
      } catch (_) {
        return const TaskAuthValidationResult(
          authenticated: false,
          status: 401,
          error: 'Unauthorized: Invalid or expired authentication token.',
        );
      }
    }
  }

  return const TaskAuthValidationResult(
    authenticated: false,
    status: 401,
    error: 'Unauthorized: Missing or invalid authentication credentials.',
  );
}

/// Processes an incoming ExternalTaskEvent and updates/creates the corresponding TaskInstance in Firestore.
Future<TaskEventResult> processExternalTaskEvent(
  FirestoreDatabase db,
  ExternalTaskEvent event, {
  DateTime? now,
}) async {
  final instancesRef =
      db.collection('users').doc(event.userId).collection('instances');

  // Query instances matching the date and provider/external ID binding
  final querySnap = await instancesRef
      .where('scheduledDate', '==', event.date)
      .where('integrationBinding.providerId', '==', event.providerId)
      .where('integrationBinding.externalId', '==', event.externalId)
      .limit(1)
      .get();

  final nowUtc = now ?? DateTime.now().toUtc();
  final nowIso = nowUtc.toIso8601String();

  var targetStatus = 'pending';
  String? completedAt;
  String? completedByUserId;

  if (event.action == 'completed') {
    targetStatus = 'completed';
    completedAt = event.timestamp ?? nowIso;
    completedByUserId = event.userId;
  } else if (event.action == 'dismissed') {
    targetStatus = 'dismissed';
  } else if (event.action == 'uncompleted') {
    targetStatus = 'pending';
    completedAt = null;
    completedByUserId = null;
  }

  if (!querySnap.empty) {
    // Update existing instance
    final doc = querySnap.docs.first;
    final existingData = doc.data() ?? {};
    final updatedCompletedByUserIds = List<String>.from(
      (existingData['completedByUserIds'] as List?) ?? [],
    );

    if (event.action == 'completed') {
      if (!updatedCompletedByUserIds.contains(event.userId)) {
        updatedCompletedByUserIds.add(event.userId);
      }
    } else if (event.action == 'uncompleted') {
      updatedCompletedByUserIds.removeWhere((id) => id == event.userId);
    }

    await doc.ref.update({
      'status': targetStatus,
      'completedAt': completedAt,
      'completedByUserId': completedByUserId,
      'completedByUserIds': updatedCompletedByUserIds,
      'updatedAt': nowIso,
      'lastModifiedByUserId': event.userId,
    });

    return TaskEventResult(
      success: true,
      instanceId: doc.id,
      actionApplied: event.action,
      createdNewInstance: false,
    );
  }

  // If no instance exists for that day, check if a parent TaskSchedule template exists
  final schedulesRef =
      db.collection('users').doc(event.userId).collection('tasks');
  final scheduleSnap = await schedulesRef
      .where('integrationBinding.providerId', '==', event.providerId)
      .where('integrationBinding.externalId', '==', event.externalId)
      .limit(1)
      .get();

  var scheduleId = 'SCHED-${event.providerId}-${event.externalId}';
  var title = '${event.providerId}: ${event.externalId}';
  var description = 'Auto-tracked from ${event.providerId}';

  if (!scheduleSnap.empty) {
    final sDoc = scheduleSnap.docs.first;
    scheduleId = sDoc.id;
    final sData = sDoc.data() ?? {};
    if (sData['title'] is String) title = sData['title'] as String;
    if (sData['description'] is String)
      description = sData['description'] as String;
  }

  // Create a Just-in-Time TaskInstance document
  final newInstanceRef = instancesRef.doc();
  final newInstance = <String, dynamic>{
    'id': newInstanceRef.id,
    'scheduleId': scheduleId,
    'ruleId': 'RULE-EXT-SYNC',
    'title': title,
    'description': description,
    'scheduledDate': event.date,
    'startRelativeTime': {'minutes': 0},
    'dueRelativeTime': {'minutes': 1439},
    'isFamily': false,
    'status': targetStatus,
    'completedAt': completedAt,
    'completedByUserId': completedByUserId,
    'completedByUserIds':
        completedByUserId != null ? [completedByUserId] : <String>[],
    'integrationBinding': {
      'providerId': event.providerId,
      'entityType': event.entityType,
      'externalId': event.externalId,
      'bidirectional': true,
    },
    'updatedAt': nowIso,
    'createdAt': nowIso,
    'lastModifiedByUserId': event.userId,
  };

  await newInstanceRef.set(newInstance);

  return TaskEventResult(
    success: true,
    instanceId: newInstanceRef.id,
    actionApplied: event.action,
    createdNewInstance: true,
    message: 'Created and applied ${event.action} to new TaskInstance',
  );
}

/// HTTP endpoint handler for reportExternalTaskEvent.
Future<void> handleReportExternalTaskEvent(
  HttpRequest req,
  HttpResponse res, {
  FirestoreDatabase? db,
  AuthService? auth,
}) async {
  if (req.method != 'POST') {
    res
        .status(405)
        .json({'success': false, 'error': 'Method Not Allowed. Use POST.'});
    return;
  }

  final validation = validateTaskEvent(req.body);
  if (!validation.valid || validation.event == null) {
    logWarn(
        'Invalid external task event received: ${req.body} ${validation.error}');
    res.status(400).json({'success': false, 'error': validation.error});
    return;
  }

  final authResult = await authenticateTaskEventRequest(
    req.headers,
    validation.event!.userId,
    auth: auth,
  );
  if (!authResult.authenticated) {
    logWarn(
      'Unauthorized external task event attempt for user ${validation.event!.userId}: ${authResult.error}',
    );
    res
        .status(authResult.status ?? 401)
        .json({'success': false, 'error': authResult.error});
    return;
  }

  try {
    final firestoreDb = db ?? getFirebaseAdminDb();
    final result =
        await processExternalTaskEvent(firestoreDb, validation.event!);
    logInfo(
      'Processed task event for user ${validation.event!.userId}, provider ${validation.event!.providerId}: ${validation.event!.action}',
    );
    res.status(200).json(result.toJson());
  } catch (error) {
    final errorMessage = error.toString().replaceFirst('Exception: ', '');
    logError('Error processing external task event:', error);
    res.status(500).json({'success': false, 'error': errorMessage});
  }
}
