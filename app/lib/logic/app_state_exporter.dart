import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_logger.dart';
import 'auth_repository.dart';
import 'firestore_extensions.dart';
import 'firestore_paths.dart';
import 'hive_local_data_source.dart';
import 'task_repository.dart';
import 'utils/app_version.dart';
import 'utils/pii_sanitizer.dart';

final appStateExporterProvider = Provider<AppStateExporter>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final hiveDataSource = ref.watch(hiveLocalDataSourceProvider);
  final logger = ref.watch(appLoggerProvider);
  return AppStateExporter(
    firestore: firestore,
    authRepository: authRepo,
    hiveDataSource: hiveDataSource,
    logger: logger,
  );
});

class AppStateExporter {
  final FirebaseFirestore? _firestore;
  final AuthRepository? _authRepository;
  final HiveLocalDataSource _hiveDataSource;
  final AppLogger? _logger;

  AppStateExporter({
    FirebaseFirestore? firestore,
    AuthRepository? authRepository,
    required HiveLocalDataSource hiveDataSource,
    AppLogger? logger,
  }) : _firestore = firestore,
       _authRepository = authRepository,
       _hiveDataSource = hiveDataSource,
       _logger = logger;

  /// Masks an email address by delegating to [PiiSanitizer.maskEmail].
  static String? maskEmail(String? email) => PiiSanitizer.maskEmail(email);

  /// Masks a general PII string by delegating to [PiiSanitizer.maskPii].
  static String? maskPii(String? value) => PiiSanitizer.maskPii(value);

  /// Sanitizes [value] into a JSON-encodable structure by delegating to [PiiSanitizer.sanitize].
  dynamic sanitizeForJson(
    dynamic value, {
    bool isEmailKey = false,
    bool isPiiKey = false,
  }) =>
      PiiSanitizer.sanitize(value, isEmailKey: isEmailKey, isPiiKey: isPiiKey);

  Future<Map<String, dynamic>> exportStateRaw() async {
    bool isOffline = false;
    final User? user = _authRepository?.currentUser;
    final String? uid = user?.uid;

    final exportMetadata = <String, dynamic>{
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': AppVersion.display,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'isOffline': false,
    };

    Map<String, dynamic> authState = {};
    if (user != null) {
      authState = {
        'uid': user.uid,
        'email': maskEmail(user.email),
        'isAnonymous': user.isAnonymous,
        'emailVerified': user.emailVerified,
        'creationTime': user.metadata.creationTime?.toUtc().toIso8601String(),
        'lastSignInTime': user.metadata.lastSignInTime
            ?.toUtc()
            .toIso8601String(),
      };
    }

    final localHiveState = _hiveDataSource.exportRawState();

    Map<String, dynamic> remoteFirebaseState = {
      'status': 'success',
      'errorMessage': null,
      'userProfileDoc': null,
      'settingsDoc': null,
      'tasks': <dynamic>[],
      'instances': <dynamic>[],
      'familyDoc': null,
      'familyTasks': <dynamic>[],
      'familyInstances': <dynamic>[],
      'invites': <dynamic>[],
    };

    if (_firestore == null || uid == null || uid.isEmpty) {
      isOffline = true;
      remoteFirebaseState['status'] = 'error';
      remoteFirebaseState['errorMessage'] = uid == null || uid.isEmpty
          ? 'No authenticated user'
          : 'Firestore instance not available';
    } else {
      final List<String> errors = [];
      bool networkErrorOccurred = false;
      final userDocRef = _firestore.collection(FirestorePaths.users).doc(uid);
      final String? email = user?.email;

      bool isNetworkOrTimeoutError(dynamic e) {
        if (e is TimeoutException || e is SocketException) return true;
        if (e is FirebaseException) {
          final code = e.code.toLowerCase();
          final message = (e.message ?? '').toLowerCase();
          if (code == 'unavailable' ||
              code == 'network-request-failed' ||
              code == 'deadline-exceeded' ||
              code == 'cancelled' ||
              message.contains('network') ||
              message.contains('timeout') ||
              message.contains('offline')) {
            return true;
          }
        }
        return false;
      }

      final phase1Futures = <Future<void>>[
        () async {
          try {
            final userSnap = await userDocRef.safeGet(
              timeout: const Duration(seconds: 5),
            );
            if (userSnap.exists && userSnap.data() != null) {
              remoteFirebaseState['userProfileDoc'] = userSnap.data();
            }
          } catch (e) {
            if (isNetworkOrTimeoutError(e)) {
              networkErrorOccurred = true;
            }
            errors.add('userProfileDoc: $e');
          }
        }(),
        () async {
          try {
            final settingsSnap = await userDocRef
                .collection(FirestorePaths.settings)
                .doc('agile')
                .safeGet(timeout: const Duration(seconds: 5));
            if (settingsSnap.exists && settingsSnap.data() != null) {
              remoteFirebaseState['settingsDoc'] = settingsSnap.data();
            }
          } catch (e) {
            if (isNetworkOrTimeoutError(e)) {
              networkErrorOccurred = true;
            }
            errors.add('settingsDoc: $e');
          }
        }(),
        () async {
          try {
            final tasksQuery = await userDocRef
                .collection(FirestorePaths.tasks)
                .limit(500)
                .safeGet(timeout: const Duration(seconds: 5));
            remoteFirebaseState['tasks'] = tasksQuery.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
          } catch (e) {
            if (isNetworkOrTimeoutError(e)) {
              networkErrorOccurred = true;
            }
            errors.add('tasks: $e');
          }
        }(),
        () async {
          try {
            final instancesQuery = await userDocRef
                .collection(FirestorePaths.instances)
                .limit(500)
                .safeGet(timeout: const Duration(seconds: 5));
            remoteFirebaseState['instances'] = instancesQuery.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
          } catch (e) {
            if (isNetworkOrTimeoutError(e)) {
              networkErrorOccurred = true;
            }
            errors.add('instances: $e');
          }
        }(),
      ];

      if (email != null && email.isNotEmpty) {
        phase1Futures.add(() async {
          try {
            final invitesQuery = await _firestore
                .collection(FirestorePaths.invites)
                .where('toEmail', isEqualTo: email.trim().toLowerCase())
                .limit(500)
                .safeGet(timeout: const Duration(seconds: 5));
            remoteFirebaseState['invites'] = invitesQuery.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
          } catch (e) {
            if (isNetworkOrTimeoutError(e)) {
              networkErrorOccurred = true;
            }
            errors.add('invites: $e');
          }
        }());
      }

      await Future.wait(phase1Futures);

      final userProfileData =
          remoteFirebaseState['userProfileDoc'] as Map<String, dynamic>?;
      String? familyId = userProfileData?['familyId'] as String?;
      if (familyId == null || familyId.isEmpty) {
        final localSettings =
            localHiveState['settings'] as Map<String, dynamic>?;
        familyId = localSettings?['familyId'] as String?;
      }

      if (familyId != null && familyId.isNotEmpty) {
        final familyRef = _firestore
            .collection(FirestorePaths.families)
            .doc(familyId);

        final phase2Futures = <Future<void>>[
          () async {
            try {
              final familySnap = await familyRef.safeGet(
                timeout: const Duration(seconds: 5),
              );
              if (familySnap.exists && familySnap.data() != null) {
                final familyData = familySnap.data()!;
                remoteFirebaseState['familyDoc'] = {
                  'id': familySnap.id,
                  ...familyData,
                };

                final membersMap =
                    familyData['members'] as Map<String, dynamic>?;
                if (membersMap != null && membersMap.isNotEmpty) {
                  final memberProfiles = <String, dynamic>{};
                  for (final memberUid in membersMap.keys) {
                    try {
                      final memberDocSnap = await _firestore
                          .collection(FirestorePaths.users)
                          .doc(memberUid)
                          .safeGet(timeout: const Duration(seconds: 5));
                      if (memberDocSnap.exists &&
                          memberDocSnap.data() != null) {
                        memberProfiles[memberUid] = memberDocSnap.data();
                      }
                    } catch (e) {
                      errors.add('memberProfileDoc ($memberUid): $e');
                    }
                  }
                  if (memberProfiles.isNotEmpty) {
                    remoteFirebaseState['familyMemberProfiles'] =
                        memberProfiles;
                  }
                }
              }
            } catch (e) {
              if (isNetworkOrTimeoutError(e)) {
                networkErrorOccurred = true;
              }
              errors.add('familyDoc: $e');
            }
          }(),
          () async {
            try {
              final familyTasksQuery = await familyRef
                  .collection(FirestorePaths.tasks)
                  .limit(500)
                  .safeGet(timeout: const Duration(seconds: 5));
              remoteFirebaseState['familyTasks'] = familyTasksQuery.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList();
            } catch (e) {
              if (isNetworkOrTimeoutError(e)) {
                networkErrorOccurred = true;
              }
              errors.add('familyTasks: $e');
            }
          }(),
          () async {
            try {
              final familyInstancesQuery = await familyRef
                  .collection(FirestorePaths.instances)
                  .limit(500)
                  .safeGet(timeout: const Duration(seconds: 5));
              remoteFirebaseState['familyInstances'] = familyInstancesQuery.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList();
            } catch (e) {
              if (isNetworkOrTimeoutError(e)) {
                networkErrorOccurred = true;
              }
              errors.add('familyInstances: $e');
            }
          }(),
        ];

        await Future.wait(phase2Futures);
      }

      if (errors.isNotEmpty) {
        remoteFirebaseState['status'] = 'error';
        remoteFirebaseState['errorMessage'] = errors.join('; ');
        if (networkErrorOccurred || errors.length >= phase1Futures.length) {
          isOffline = true;
        }
      }
    }

    exportMetadata['isOffline'] = isOffline;

    final Map<String, dynamic> diagnostics = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
    };

    // 1. Auth Diagnostics
    final authDiagnostics = <String, dynamic>{
      'hasUser': user != null,
      'uid': uid,
      'emailVerified': user?.emailVerified,
      'isAnonymous': user?.isAnonymous,
    };
    if (user != null) {
      final tokenWatch = Stopwatch()..start();
      try {
        final token = await user.getIdToken(false);
        authDiagnostics['cachedToken'] = {
          'success': true,
          'durationMs': tokenWatch.elapsedMilliseconds,
          'tokenPresent': token != null && token.isNotEmpty,
        };
      } catch (e) {
        authDiagnostics['cachedToken'] = {
          'success': false,
          'durationMs': tokenWatch.elapsedMilliseconds,
          'error': e.toString(),
        };
      }

      final forceTokenWatch = Stopwatch()..start();
      try {
        final refreshedToken = await user.getIdToken(true);
        authDiagnostics['refreshedToken'] = {
          'success': true,
          'durationMs': forceTokenWatch.elapsedMilliseconds,
          'tokenPresent': refreshedToken != null && refreshedToken.isNotEmpty,
        };
      } catch (e) {
        authDiagnostics['refreshedToken'] = {
          'success': false,
          'durationMs': forceTokenWatch.elapsedMilliseconds,
          'error': e.toString(),
        };
      }

      try {
        final tokenResult = await user.getIdTokenResult(false);
        authDiagnostics['tokenResult'] = {
          'issuedAt': tokenResult.issuedAtTime?.toUtc().toIso8601String(),
          'expirationTime': tokenResult.expirationTime
              ?.toUtc()
              .toIso8601String(),
          'authTime': tokenResult.authTime?.toUtc().toIso8601String(),
          'signInProvider': tokenResult.signInProvider,
        };
      } catch (e) {
        authDiagnostics['tokenResult'] = {'error': e.toString()};
      }
    }
    diagnostics['auth'] = authDiagnostics;

    // 2. Firestore Connectivity Probes
    if (_firestore != null && uid != null && uid.isNotEmpty) {
      final firestoreProbes = <String, dynamic>{};
      final userDocRef = _firestore.collection(FirestorePaths.users).doc(uid);

      // Probe A: Server get()
      final serverGetWatch = Stopwatch()..start();
      try {
        final snap = await userDocRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 4));
        firestoreProbes['serverGet'] = {
          'success': true,
          'durationMs': serverGetWatch.elapsedMilliseconds,
          'exists': snap.exists,
        };
      } catch (e) {
        firestoreProbes['serverGet'] = {
          'success': false,
          'durationMs': serverGetWatch.elapsedMilliseconds,
          'error': e.toString(),
          'errorType': e.runtimeType.toString(),
        };
      }

      // Probe B: Cache get()
      final cacheGetWatch = Stopwatch()..start();
      try {
        final snap = await userDocRef
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 4));
        firestoreProbes['cacheGet'] = {
          'success': true,
          'durationMs': cacheGetWatch.elapsedMilliseconds,
          'exists': snap.exists,
        };
      } catch (e) {
        firestoreProbes['cacheGet'] = {
          'success': false,
          'durationMs': cacheGetWatch.elapsedMilliseconds,
          'error': e.toString(),
          'errorType': e.runtimeType.toString(),
        };
      }

      // Probe C: snapshots().first
      final streamWatch = Stopwatch()..start();
      try {
        final snap = await userDocRef.snapshots().first.timeout(
          const Duration(seconds: 4),
        );
        firestoreProbes['snapshotStream'] = {
          'success': true,
          'durationMs': streamWatch.elapsedMilliseconds,
          'exists': snap.exists,
        };
      } catch (e) {
        firestoreProbes['snapshotStream'] = {
          'success': false,
          'durationMs': streamWatch.elapsedMilliseconds,
          'error': e.toString(),
          'errorType': e.runtimeType.toString(),
        };
      }

      // Probe D: Query test
      final queryWatch = Stopwatch()..start();
      try {
        final qSnap = await userDocRef
            .collection(FirestorePaths.tasks)
            .limit(1)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 4));
        firestoreProbes['serverQuery'] = {
          'success': true,
          'durationMs': queryWatch.elapsedMilliseconds,
          'docsCount': qSnap.docs.length,
        };
      } catch (e) {
        firestoreProbes['serverQuery'] = {
          'success': false,
          'durationMs': queryWatch.elapsedMilliseconds,
          'error': e.toString(),
          'errorType': e.runtimeType.toString(),
        };
      }

      diagnostics['firestoreProbes'] = firestoreProbes;
    }

    final eventLogs = (_logger?.getEvents() ?? [])
        .map((e) => e.toJson())
        .toList();

    final rawMap = {
      'exportMetadata': exportMetadata,
      'auth': authState,
      'localHiveState': localHiveState,
      'remoteFirebaseState': remoteFirebaseState,
      'diagnostics': diagnostics,
      'eventLogs': eventLogs,
    };

    return PiiSanitizer.sanitize(rawMap) as Map<String, dynamic>;
  }

  Future<String> exportStateJson({bool pretty = true}) async {
    final rawMap = await exportStateRaw();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(rawMap);
    }
    return jsonEncode(rawMap);
  }
}
