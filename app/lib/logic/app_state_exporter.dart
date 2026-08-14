import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'utils/app_version.dart';
import 'auth_repository.dart';
import 'civil_day.dart';
import 'error_handler.dart';
import 'hive_local_data_source.dart';
import 'l10n_extension.dart';
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
  final AuthRepository? _authRepository;
  final HiveLocalDataSource _hiveDataSource;

  AppStateExporter({
    FirebaseFirestore? firestore,
    AuthRepository? authRepository,
    required HiveLocalDataSource hiveDataSource,
  })  : _firestore = firestore,
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

  static String? maskPii(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return '${trimmed[0]}***';
  }

  static bool _isPiiKey(String lowerKey) {
    if (lowerKey.contains('email')) return false;
    if (lowerKey == 'id' ||
        lowerKey == 'ids' ||
        lowerKey.endsWith('id') ||
        lowerKey.endsWith('_id') ||
        lowerKey.endsWith('ids') ||
        lowerKey.endsWith('_ids')) {
      return false;
    }
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
      'member',
    ];
    if (piiKeywords.any((k) => lowerKey.contains(k))) return true;
    if (lowerKey == 'name') return true;
    return false;
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
        'lastSignInTime':
            user.metadata.lastSignInTime?.toUtc().toIso8601String(),
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
      final userDocRef = _firestore.collection('users').doc(uid);
      final String? email = user?.email;

      final futures = <Future<void>>[
        userDocRef
            .get()
            .timeout(const Duration(seconds: 5))
            .then((userDocSnap) {
          final userProfileData = userDocSnap.data();
          if (userDocSnap.exists && userProfileData != null) {
            remoteFirebaseState['userProfileDoc'] = userProfileData;
          }
        }).catchError((e) {
          errors.add('userProfileDoc: $e');
        }),
        userDocRef
            .collection('settings')
            .doc('agile')
            .get()
            .timeout(const Duration(seconds: 5))
            .then((settingsSnap) {
          if (settingsSnap.exists && settingsSnap.data() != null) {
            remoteFirebaseState['settingsDoc'] = settingsSnap.data();
          }
        }).catchError((e) {
          errors.add('settingsDoc: $e');
        }),
        userDocRef
            .collection('tasks')
            .limit(500)
            .get()
            .timeout(const Duration(seconds: 5))
            .then((tasksQuery) {
          remoteFirebaseState['tasks'] = tasksQuery.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        }).catchError((e) {
          errors.add('tasks: $e');
        }),
        userDocRef
            .collection('instances')
            .limit(500)
            .get()
            .timeout(const Duration(seconds: 5))
            .then((instancesQuery) {
          remoteFirebaseState['instances'] = instancesQuery.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        }).catchError((e) {
          errors.add('instances: $e');
        }),
      ];

      if (email != null && email.isNotEmpty) {
        futures.add(
          _firestore
              .collection('invites')
              .where('toEmail', isEqualTo: email.trim().toLowerCase())
              .limit(500)
              .get()
              .timeout(const Duration(seconds: 5))
              .then((invitesQuery) {
            remoteFirebaseState['invites'] = invitesQuery.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
          }).catchError((e) {
            errors.add('invites: $e');
          }),
        );
      }

      await Future.wait(futures);

      final userProfileData =
          remoteFirebaseState['userProfileDoc'] as Map<String, dynamic>?;
      String? familyId = userProfileData?['familyId'] as String?;
      if (familyId == null || familyId.isEmpty) {
        final localSettings =
            localHiveState['settings'] as Map<String, dynamic>?;
        familyId = (localSettings?['familyId'] ?? localHiveState['familyId'])
            as String?;
      }

      if (familyId != null && familyId.isNotEmpty) {
        final familyRef = _firestore.collection('families').doc(familyId);

        final familyFutures = <Future<void>>[
          familyRef
              .get()
              .timeout(const Duration(seconds: 5))
              .then((familySnap) {
            if (familySnap.exists && familySnap.data() != null) {
              remoteFirebaseState['familyDoc'] = {
                'id': familySnap.id,
                ...familySnap.data()!,
              };
            }
          }).catchError((e) {
            errors.add('familyDoc: $e');
          }),
          familyRef
              .collection('tasks')
              .limit(500)
              .get()
              .timeout(const Duration(seconds: 5))
              .then((familyTasksQuery) {
            remoteFirebaseState['familyTasks'] = familyTasksQuery.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
          }).catchError((e) {
            errors.add('familyTasks: $e');
          }),
          familyRef
              .collection('instances')
              .limit(500)
              .get()
              .timeout(const Duration(seconds: 5))
              .then((familyInstancesQuery) {
            remoteFirebaseState['familyInstances'] = familyInstancesQuery.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
          }).catchError((e) {
            errors.add('familyInstances: $e');
          }),
        ];

        await Future.wait(familyFutures);
      }

      if (errors.isNotEmpty) {
        remoteFirebaseState['status'] = 'error';
        remoteFirebaseState['errorMessage'] = errors.join('; ');
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
      if (isPiiKey) return maskPii(value);
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
        final entryIsEmailKey = isEmailKey || lowerKey.contains('email');
        final entryIsPiiKey = isPiiKey || _isPiiKey(lowerKey);
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
            (e) => sanitizeForJson(
              e,
              isEmailKey: isEmailKey,
              isPiiKey: isPiiKey,
            ),
          )
          .toList();
    }

    try {
      final dynamic json = (value as dynamic).toJson();
      return sanitizeForJson(
        json,
        isEmailKey: isEmailKey,
        isPiiKey: isPiiKey,
      );
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
        if (route == null || route.isCurrent) {
          isPopped = true;
          navigator.pop();
        }
      }
    }

    dialogContextCompleter.future.then((dialogCtx) {
      if (isDismissed) {
        popDialog(dialogCtx);
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
      if (dialogContextCompleter.isCompleted) {
        final dialogCtx = await dialogContextCompleter.future;
        popDialog(dialogCtx);
      }
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
            final Rect sharePositionOrigin = (box != null && box.hasSize)
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
          await Clipboard.setData(ClipboardData(text: jsonString));
          if (!context.mounted) return;
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(context.l10n.debugStateCopiedToClipboard),
            ),
          );
        }
      } finally {
        await dismissProgressDialog();
      }
    } catch (e, stackTrace) {
      if (!context.mounted) return;
      final errorHandler = ErrorHandler();
      final report = errorHandler.report(e, stackTrace: stackTrace);
      errorHandler.showErrorDialog(context, report);
    }
  }
}

