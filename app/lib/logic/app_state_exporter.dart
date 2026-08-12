import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'auth_repository.dart';
import 'civil_day.dart';
import 'error_handler.dart';
import 'hive_local_data_source.dart';
import 'relative_time.dart';
import 'task_repository.dart';

final appStateExporterProvider = Provider<AppStateExporter>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final hiveDataSource = ref.watch(hiveLocalDataSourceProvider);
  return AppStateExporter(
    firestore: firestore,
    authRepository: authRepo,
    hiveDataSource: hiveDataSource,
  );
});

class AppStateExporter {
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _firebaseAuth;
  final AuthRepository? _authRepository;
  final HiveLocalDataSource _hiveDataSource;

  AppStateExporter({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    AuthRepository? authRepository,
    required HiveLocalDataSource hiveDataSource,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth,
       _authRepository = authRepository,
       _hiveDataSource = hiveDataSource;

  static String? maskEmail(String? email) {
    if (email == null) return null;
    final trimmed = email.trim();
    if (trimmed.isEmpty) return trimmed;
    final parts = trimmed.split('@');
    if (parts.length != 2) return '***';
    final local = parts[0];
    final domain = parts[1];
    if (local.isEmpty) return '***@$domain';
    return '${local[0]}***@$domain';
  }

  Future<Map<String, dynamic>> exportStateRaw() async {
    bool isOffline = false;
    final User? user =
        _firebaseAuth?.currentUser ?? _authRepository?.currentUser;
    final String? uid = user?.uid;

    final exportMetadata = <String, dynamic>{
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': '1.0.0+1',
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
      remoteFirebaseState['status'] = 'error';
      remoteFirebaseState['errorMessage'] = uid == null || uid.isEmpty
          ? 'No authenticated user'
          : 'Firestore instance not available';
    } else {
      try {
        final userDocRef = _firestore.collection('users').doc(uid);
        final userDocSnap = await userDocRef.get().timeout(
          const Duration(seconds: 5),
        );
        final userProfileData = userDocSnap.data();
        if (userDocSnap.exists && userProfileData != null) {
          remoteFirebaseState['userProfileDoc'] = userProfileData;
        }

        final settingsSnap = await userDocRef
            .collection('settings')
            .doc('agile')
            .get()
            .timeout(const Duration(seconds: 5));
        if (settingsSnap.exists && settingsSnap.data() != null) {
          remoteFirebaseState['settingsDoc'] = settingsSnap.data();
        }

        final tasksQuery = await userDocRef
            .collection('tasks')
            .get()
            .timeout(const Duration(seconds: 5));
        remoteFirebaseState['tasks'] = tasksQuery.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();

        final instancesQuery = await userDocRef
            .collection('instances')
            .get()
            .timeout(const Duration(seconds: 5));
        remoteFirebaseState['instances'] = instancesQuery.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();

        final String? familyId = userProfileData?['familyId'] as String?;
        if (familyId != null && familyId.isNotEmpty) {
          final familyRef = _firestore.collection('families').doc(familyId);
          final familySnap = await familyRef
              .get()
              .timeout(const Duration(seconds: 5));
          if (familySnap.exists && familySnap.data() != null) {
            remoteFirebaseState['familyDoc'] = {
              'id': familySnap.id,
              ...familySnap.data()!,
            };
          }

          final familyTasksQuery = await familyRef
              .collection('tasks')
              .get()
              .timeout(const Duration(seconds: 5));
          remoteFirebaseState['familyTasks'] = familyTasksQuery.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();

          final familyInstancesQuery = await familyRef
              .collection('instances')
              .get()
              .timeout(const Duration(seconds: 5));
          remoteFirebaseState['familyInstances'] = familyInstancesQuery.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        }

        final String? email = user?.email;
        if (email != null && email.isNotEmpty) {
          final invitesQuery = await _firestore
              .collection('invites')
              .where('toEmail', isEqualTo: email.trim().toLowerCase())
              .get()
              .timeout(const Duration(seconds: 5));
          remoteFirebaseState['invites'] = invitesQuery.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        }
      } catch (e) {
        isOffline = true;
        remoteFirebaseState['status'] = 'error';
        remoteFirebaseState['errorMessage'] = e.toString();
      }
    }

    exportMetadata['isOffline'] = isOffline;

    final rawMap = {
      'exportMetadata': exportMetadata,
      'auth': authState,
      'localHiveState': localHiveState,
      'remoteFirebaseState': remoteFirebaseState,
    };

    return sanitizeForJson(rawMap) as Map<String, dynamic>;
  }

  Future<String> exportStateJson({bool pretty = true}) async {
    final rawMap = await exportStateRaw();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(rawMap);
    }
    return jsonEncode(rawMap);
  }

  dynamic sanitizeForJson(dynamic value) {
    if (value == null) return null;
    if (value is num || value is bool) return value;

    if (value is String) {
      return value;
    }

    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }

    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }

    if (value is DocumentReference) {
      return value.path;
    }

    if (value is CivilDay) {
      return value.toJson();
    }

    if (value is RelativeTime) {
      return value.toJson();
    }

    if (value is TimeOfDay) {
      return {'hour': value.hour, 'minute': value.minute};
    }

    if (value is Enum) {
      return value.name;
    }

    if (value is Duration) {
      return value.inMilliseconds;
    }

    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }

    if (value is Map) {
      final Map<String, dynamic> result = {};
      value.forEach((k, v) {
        final keyStr = k.toString();
        final lowerKey = keyStr.toLowerCase();
        final isEmailKey =
            lowerKey == 'email' || lowerKey.endsWith('email');
        if (isEmailKey && v is String) {
          result[keyStr] = maskEmail(v);
        } else {
          result[keyStr] = sanitizeForJson(v);
        }
      });
      return result;
    }

    if (value is Iterable) {
      return value.map((e) => sanitizeForJson(e)).toList();
    }

    try {
      final dynamic json = (value as dynamic).toJson();
      return sanitizeForJson(json);
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> shareDebugState(BuildContext context) async {
    bool progressDialogShowing = true;
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final jsonString = await exportStateJson(pretty: true);

      if (progressDialogShowing) {
        if (rootNavigator.canPop()) {
          rootNavigator.pop();
        }
        progressDialogShowing = false;
      }

      if (!context.mounted) return;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'debug_app_state_$timestamp.json';

      bool shared = false;

      if (!kIsWeb) {
        try {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsString(jsonString);

          final xFile = XFile(
            file.path,
            mimeType: 'application/json',
            name: fileName,
          );
          await Share.shareXFiles(
            [xFile],
            subject: 'App State Debug Export',
            text: 'Debug app state JSON export for NothingEverHappens.',
          );
          shared = true;
        } catch (e) {
          debugPrint('Share file failed, falling back to clipboard: $e');
        }
      }

      if (!shared) {
        await Clipboard.setData(ClipboardData(text: jsonString));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debug state JSON copied to clipboard.'),
          ),
        );
      }
    } catch (e, stackTrace) {
      if (progressDialogShowing) {
        if (rootNavigator.canPop()) {
          rootNavigator.pop();
        }
        progressDialogShowing = false;
      }

      if (!context.mounted) return;
      final errorHandler = ErrorHandler();
      final report = errorHandler.report(e, stackTrace: stackTrace);
      errorHandler.showErrorDialog(context, report);
    }
  }
}
