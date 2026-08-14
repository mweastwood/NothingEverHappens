import 'dart:async';
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
import 'l10n_extension.dart';
import 'relative_time.dart';
import 'task_repository.dart';
import 'utils/app_version.dart';

final appStateExporterProvider = Provider<AppStateExporter>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final hiveDataSource = ref.watch(hiveLocalDataSourceProvider);
  final errorHandler = ref.watch(errorHandlerProvider);
  return AppStateExporter(
    firestore: firestore,
    authRepository: authRepo,
    hiveDataSource: hiveDataSource,
    errorHandler: errorHandler,
  );
});

class AppStateExporter {
  final FirebaseFirestore? _firestore;
  final AuthRepository? _authRepository;
  final HiveLocalDataSource _hiveDataSource;
  final ErrorHandler? _errorHandler;

  AppStateExporter({
    FirebaseFirestore? firestore,
    AuthRepository? authRepository,
    required HiveLocalDataSource hiveDataSource,
    ErrorHandler? errorHandler,
  })  : _firestore = firestore,
        _authRepository = authRepository,
        _hiveDataSource = hiveDataSource,
        _errorHandler = errorHandler;

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

  static String? maskPii(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return '${trimmed[0]}***';
  }

  static bool _isNonPiiKey(String key) {
    final lowerKey = key.toLowerCase();
    if (lowerKey.contains('email')) return false;
    if (lowerKey == 'id' ||
        lowerKey == 'ids' ||
        lowerKey == 'uid' ||
        lowerKey == 'uids' ||
        lowerKey == 'role' ||
        lowerKey == 'status') {
      return true;
    }
    if (lowerKey.endsWith('_id') ||
        lowerKey.endsWith('_ids') ||
        lowerKey.endsWith('-id') ||
        lowerKey.endsWith('-ids') ||
        lowerKey.endsWith('_uid') ||
        lowerKey.endsWith('_uids') ||
        lowerKey.endsWith('-uid') ||
        lowerKey.endsWith('-uids')) {
      return true;
    }
    if (key.endsWith('Id') ||
        key.endsWith('Ids') ||
        key.endsWith('ID') ||
        key.endsWith('IDS') ||
        key.endsWith('Uid') ||
        key.endsWith('Uids')) {
      return true;
    }
    return false;
  }

  static bool _isPiiKey(String key) {
    if (_isNonPiiKey(key)) return false;
    final lowerKey = key.toLowerCase();
    const piiKeywords = [
      'displayname',
      'display_name',
      'fullname',
      'full_name',
      'firstname',
      'first_name',
      'lastname',
      'last_name',
      'username',
      'user_name',
      'phonenumber',
      'phone_number',
      'phone',
      'photourl',
      'photo_url',
      'photo',
      'avatar',
      'picture',
      'address',
      'street',
      'zipcode',
      'postalcode',
      'bio',
      'sender',
      'recipient',
      'inviter',
      'invitee',
      'profile',
    ];
    if (piiKeywords.any((k) => lowerKey.contains(k))) return true;
    if (lowerKey == 'name' || lowerKey == 'member' || lowerKey == 'members') {
      return true;
    }
    return false;
  }

  static bool _isRoleOrStatusValue(String value) {
    final lower = value.trim().toLowerCase();
    const roleAndStatusValues = {
      'admin',
      'owner',
      'member',
      'parent',
      'non-parent',
      'viewer',
      'editor',
      'creator',
      'active',
      'pending',
      'accepted',
      'declined',
      'inactive',
    };
    return roleAndStatusValues.contains(lower);
  }

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
      final userDocRef = _firestore.collection('users').doc(uid);
      final String? email = user?.email;

      bool isNetworkOrTimeoutError(dynamic e) {
        if (e is TimeoutException || e is SocketException) return true;
        if (e is FirebaseException) {
          final code = e.code.toLowerCase();
          final message = (e.message ?? '').toLowerCase();
          if (code == 'unavailable' ||
              code == 'network-request-failed' ||
              code == 'deadline-exceeded' ||
              code == 'unknown') {
            return true;
          }
          if (message.contains('offline') ||
              message.contains('network') ||
              message.contains('unavailable') ||
              message.contains('timed out') ||
              message.contains('timeout')) {
            return true;
          }
        }
        final str = e.toString().toLowerCase();
        return str.contains('timeout') ||
            str.contains('network') ||
            str.contains('offline') ||
            str.contains('unavailable') ||
            str.contains('socketexception');
      }

      final phase1Futures = <Future<void>>[
        () async {
          try {
            final userDocSnap = await userDocRef.get().timeout(
              const Duration(seconds: 5),
            );
            final userProfileData = userDocSnap.data();
            if (userDocSnap.exists && userProfileData != null) {
              remoteFirebaseState['userProfileDoc'] = userProfileData;
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
                .collection('settings')
                .doc('agile')
                .get()
                .timeout(const Duration(seconds: 5));
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
                .collection('tasks')
                .limit(500)
                .get()
                .timeout(const Duration(seconds: 5));
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
                .collection('instances')
                .limit(500)
                .get()
                .timeout(const Duration(seconds: 5));
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
                .collection('invites')
                .where('toEmail', isEqualTo: email.trim().toLowerCase())
                .limit(500)
                .get()
                .timeout(const Duration(seconds: 5));
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
        final familyRef = _firestore.collection('families').doc(familyId);

        final phase2Futures = <Future<void>>[
          () async {
            try {
              final familySnap = await familyRef.get().timeout(
                const Duration(seconds: 5),
              );
              if (familySnap.exists && familySnap.data() != null) {
                remoteFirebaseState['familyDoc'] = {
                  'id': familySnap.id,
                  ...familySnap.data()!,
                };
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
                  .collection('tasks')
                  .limit(500)
                  .get()
                  .timeout(const Duration(seconds: 5));
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
                  .collection('instances')
                  .limit(500)
                  .get()
                  .timeout(const Duration(seconds: 5));
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

  dynamic sanitizeForJson(
    dynamic value, {
    bool isEmailKey = false,
    bool isPiiKey = false,
  }) {
    if (value == null) return null;
    if (value is num || value is bool) return value;

    if (value is String) {
      if (isEmailKey) return maskEmail(value);
      if (isPiiKey) {
        if (_isRoleOrStatusValue(value)) return value;
        return maskPii(value);
      }
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
      return sanitizeForJson(
        value.toJson(),
        isEmailKey: isEmailKey,
        isPiiKey: isPiiKey,
      );
    }

    if (value is RelativeTime) {
      return sanitizeForJson(
        value.toJson(),
        isEmailKey: isEmailKey,
        isPiiKey: isPiiKey,
      );
    }

    if (value is TimeOfDay) {
      return sanitizeForJson(
        {'hour': value.hour, 'minute': value.minute},
        isEmailKey: isEmailKey,
        isPiiKey: isPiiKey,
      );
    }

    if (value is Enum) {
      return value.name;
    }

    if (value is Duration) {
      return value.inMilliseconds;
    }

    if (value is GeoPoint) {
      return sanitizeForJson(
        {'latitude': value.latitude, 'longitude': value.longitude},
        isEmailKey: isEmailKey,
        isPiiKey: isPiiKey,
      );
    }

    if (value is Map) {
      final Map<String, dynamic> result = {};
      value.forEach((k, v) {
        final keyStr = k.toString();
        final lowerKey = keyStr.toLowerCase();
        final entryIsEmailKey = isEmailKey || lowerKey.contains('email');
        final entryIsPiiKey =
            !_isNonPiiKey(keyStr) && (isPiiKey || _isPiiKey(keyStr));
        result[keyStr] = sanitizeForJson(
          v,
          isEmailKey: entryIsEmailKey,
          isPiiKey: entryIsPiiKey,
        );
      });
      return result;
    }

    if (value is Iterable) {
      return value
          .map(
            (e) =>
                sanitizeForJson(e, isEmailKey: isEmailKey, isPiiKey: isPiiKey),
          )
          .toList();
    }

    try {
      final dynamic json = (value as dynamic).toJson();
      return sanitizeForJson(json, isEmailKey: isEmailKey, isPiiKey: isPiiKey);
    } catch (_) {
      final str = value.toString();
      if (isEmailKey) return maskEmail(str);
      if (isPiiKey) return maskPii(str);
      return str;
    }
  }

  Future<void> shareDebugState(BuildContext context) async {
    if (!context.mounted) return;

    final Completer<BuildContext> dialogContextCompleter =
        Completer<BuildContext>();
    bool isDismissed = false;
    bool isPopped = false;

    void popDialog(BuildContext ctx) {
      if (!isPopped && ctx.mounted) {
        final navigator = Navigator.of(ctx, rootNavigator: true);
        final route = ModalRoute.of(ctx);
        if (navigator.canPop() && (route == null || route.isCurrent)) {
          isPopped = true;
          navigator.pop();
        }
      }
    }

    dialogContextCompleter.future.then((dialogCtx) {
      if (!dialogCtx.mounted) return;
      if (isDismissed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          popDialog(dialogCtx);
        });
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        if (isDismissed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            popDialog(ctx);
          });
        }
        if (!dialogContextCompleter.isCompleted) {
          dialogContextCompleter.complete(ctx);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );

    Future<void> dismissProgressDialog() async {
      if (isDismissed) return;
      isDismissed = true;
      final dialogCtx = await dialogContextCompleter.future;
      if (!dialogCtx.mounted) return;
      popDialog(dialogCtx);
    }

    try {
      try {
        final jsonString = await exportStateJson(pretty: true);
        await dismissProgressDialog();

        if (!context.mounted) return;

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'debug_app_state_$timestamp.json';

        bool shared = false;

        if (!kIsWeb) {
          try {
            final RenderBox? box = context.findRenderObject() as RenderBox?;
            final Rect sharePositionOrigin =
                (box != null && box.attached && box.hasSize)
                    ? (box.localToGlobal(Offset.zero) & box.size)
                    : Rect.fromLTWH(
                        0,
                        0,
                        MediaQuery.maybeOf(context)?.size.width ?? 400,
                        (MediaQuery.maybeOf(context)?.size.height ?? 800) / 2,
                      );

            final tempDir = await getTemporaryDirectory();
            final filePath = '${tempDir.path}/$fileName';
            final tempFile = File(filePath);
            await tempFile.writeAsString(jsonString, flush: true);

            final xFile = XFile(
              filePath,
              mimeType: 'application/json',
              name: fileName,
            );

            if (!context.mounted) return;
            await Share.shareXFiles(
              [xFile],
              subject: context.l10n.debugStateShareSubject,
              text: context.l10n.debugStateShareText,
              sharePositionOrigin: sharePositionOrigin,
            );
            shared = true;
          } catch (e) {
            debugPrint('Share file failed, falling back to clipboard: $e');
          }
        }

        if (!shared) {
          if (!context.mounted) return;
          await Clipboard.setData(ClipboardData(text: jsonString));
          if (!context.mounted) return;
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(context.l10n.debugStateCopiedToClipboard)),
          );
        }
      } finally {
        await dismissProgressDialog();
      }
    } catch (e, stackTrace) {
      if (!context.mounted) return;
      final errorHandler = _errorHandler ?? ErrorHandler();
      final report = errorHandler.report(e, stackTrace: stackTrace);
      errorHandler.showErrorDialog(context, report);
    }
  }
}
