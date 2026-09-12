import '../interop/firebase_admin.dart';
import '../interop/firebase_functions.dart';
import '../interop/node_interop.dart';
import '../services/family_scheduler_service.dart';

/// Authentication result for family scheduler invocation.
class FamilySchedulerAuthResult {
  final bool authenticated;
  final int? status;
  final String? error;
  final String? uid;
  final bool isAdmin;

  const FamilySchedulerAuthResult({
    required this.authenticated,
    this.status,
    this.error,
    this.uid,
    this.isAdmin = false,
  });
}

/// Authenticates an incoming request for family scheduling.
///
/// Accepts:
/// 1. A valid service secret header (`x-service-secret`, `x-api-key`, or `Authorization: Bearer <secret>`).
/// 2. A valid Firebase Auth ID token:
///    - If [familyId] is specified, verifies that the user is a member of that family (or an admin).
///    - If [familyId] is null (processing all families), requires admin privileges or service secret.
Future<FamilySchedulerAuthResult> authenticateFamilySchedulerRequest(
  Map<String, dynamic> headers, {
  String? familyId,
  FirestoreDatabase? db,
  AuthService? auth,
  String? envSecret,
}) async {
  String? getHeader(List<String> targetNames) {
    for (final name in targetNames) {
      if (headers.containsKey(name)) {
        final val = headers[name];
        return val is List
            ? (val.isNotEmpty ? val.first.toString() : null)
            : val?.toString();
      }
    }
    final lowerTargets = targetNames.map((n) => n.toLowerCase()).toSet();
    for (final entry in headers.entries) {
      if (lowerTargets.contains(entry.key.toLowerCase())) {
        final val = entry.value;
        return val is List
            ? (val.isNotEmpty ? val.first.toString() : null)
            : val?.toString();
      }
    }
    return null;
  }

  final authHeader = getHeader(['authorization', 'Authorization']);
  final serviceKey = getHeader([
    'x-service-secret',
    'X-Service-Secret',
    'x-api-key',
    'X-Api-Key',
  ]);

  final secret =
      envSecret ?? getEnv('TASK_HUB_SECRET') ?? getEnv('SERVICE_SECRET');

  // 1. Service Secret authentication
  if (secret != null &&
      secret.isNotEmpty &&
      (serviceKey == secret || authHeader == 'Bearer $secret')) {
    return const FamilySchedulerAuthResult(authenticated: true, isAdmin: true);
  }

  // 2. Firebase ID Token authentication
  if (authHeader != null && authHeader.startsWith('Bearer ')) {
    final idToken = authHeader.substring(7).trim();
    if (idToken.isNotEmpty) {
      try {
        final firebaseAuth = auth ?? getFirebaseAdminAuth();
        final decodedToken = await firebaseAuth.verifyIdToken(idToken);
        final uid = decodedToken.uid;
        final isAdmin = decodedToken.admin == true;

        if (isAdmin) {
          return FamilySchedulerAuthResult(
            authenticated: true,
            uid: uid,
            isAdmin: true,
          );
        }

        // Processing all families requires admin or service secret
        if (familyId == null || familyId.isEmpty) {
          return const FamilySchedulerAuthResult(
            authenticated: false,
            status: 403,
            error:
                'Forbidden: Admin credentials required to schedule all families.',
          );
        }

        // Verify membership in the target family
        final firestoreDb = db ?? getFirebaseAdminDb();
        final familyDoc =
            await firestoreDb.collection('families').doc(familyId).get();

        if (!familyDoc.exists) {
          return const FamilySchedulerAuthResult(
            authenticated: false,
            status: 404,
            error: 'Family not found.',
          );
        }

        final familyData = familyDoc.data();
        final members = familyData?['members'] as Map?;
        if (members != null && members.containsKey(uid)) {
          return FamilySchedulerAuthResult(
            authenticated: true,
            uid: uid,
            isAdmin: false,
          );
        }

        return const FamilySchedulerAuthResult(
          authenticated: false,
          status: 403,
          error: 'Forbidden: User is not a member of this family.',
        );
      } catch (_) {
        return const FamilySchedulerAuthResult(
          authenticated: false,
          status: 401,
          error: 'Unauthorized: Invalid or expired authentication token.',
        );
      }
    }
  }

  return const FamilySchedulerAuthResult(
    authenticated: false,
    status: 401,
    error: 'Unauthorized: Missing or invalid authentication credentials.',
  );
}

/// HTTP endpoint handler for evaluating and spawning family schedules.
Future<void> handleProcessFamilySchedule(
  HttpRequest req,
  HttpResponse res, {
  FirestoreDatabase? db,
  AuthService? auth,
  FamilySchedulerService? service,
  String? envSecret,
}) async {
  if (req.method != 'POST') {
    res
        .status(405)
        .json({'success': false, 'error': 'Method Not Allowed. Use POST.'});
    return;
  }

  final body = req.body is Map
      ? Map<String, dynamic>.from(req.body as Map)
      : <String, dynamic>{};

  final familyId = body['familyId'] as String?;
  final now = parseScheduleTimestamp(body['now']);

  final firestoreDb = db ?? getFirebaseAdminDb();
  final authResult = await authenticateFamilySchedulerRequest(
    req.headers,
    familyId: familyId,
    db: firestoreDb,
    auth: auth,
    envSecret: envSecret,
  );

  if (!authResult.authenticated) {
    logWarn('Unauthorized family scheduler request: ${authResult.error}');
    res.status(authResult.status ?? 401).json({
      'success': false,
      'error': authResult.error,
    });
    return;
  }

  try {
    final schedulerService = service ?? FamilySchedulerService(firestoreDb);

    if (familyId != null && familyId.isNotEmpty) {
      final summary = await schedulerService.processFamily(familyId, now: now);
      if (summary.error != null) {
        logError(
          'Error evaluating family schedule for familyId=$familyId: ${summary.error}',
        );
        res.status(500).json(summary.toJson());
        return;
      }
      logInfo(
        'Processed family schedule for familyId=$familyId: spawned=${summary.instancesSpawned}, updated=${summary.instancesUpdated}, deleted=${summary.instancesDeleted}',
      );
      res.status(200).json(summary.toJson());
    } else {
      final result = await schedulerService.processAllFamilies(now: now);
      if (!result.success) {
        logWarn(
          'Processed all family schedules with errors: families=${result.familiesProcessed}, spawned=${result.totalInstancesSpawned}, updated=${result.totalInstancesUpdated}',
        );
        res.status(500).json(result.toJson());
        return;
      }
      logInfo(
        'Processed all family schedules: families=${result.familiesProcessed}, spawned=${result.totalInstancesSpawned}, updated=${result.totalInstancesUpdated}',
      );
      res.status(200).json(result.toJson());
    }
  } catch (error) {
    logError('Error executing family scheduler handler:', error);
    final errorMessage = error.toString().replaceFirst('Exception: ', '');
    res.status(500).json({'success': false, 'error': errorMessage});
  }
}

/// Parses an incoming dynamic timestamp from HTTP payloads or JS interop.
/// Supports epoch milliseconds as `int`, `num`, or numeric `String`, ISO strings, and `DateTime`.
DateTime? parseScheduleTimestamp(dynamic now) {
  if (now == null) return null;
  if (now is DateTime) return now.toUtc();
  if (now is num) {
    return DateTime.fromMillisecondsSinceEpoch(now.toInt(), isUtc: true);
  }
  final str = now.toString().trim();
  if (str.isEmpty) return null;
  final asInt = int.tryParse(str);
  if (asInt != null) {
    return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
  }
  return DateTime.tryParse(str)?.toUtc();
}

/// Direct invocation helper for family scheduling, used by JS interop and direct calls.
Future<dynamic> processFamilyScheduleDirect(
  FirestoreDatabase db, {
  String? familyId,
  dynamic now,
}) async {
  final service = FamilySchedulerService(db);
  final effectiveNow = parseScheduleTimestamp(now);
  if (familyId != null && familyId.isNotEmpty) {
    return service.processFamily(familyId, now: effectiveNow);
  } else {
    return service.processAllFamilies(now: effectiveNow);
  }
}
