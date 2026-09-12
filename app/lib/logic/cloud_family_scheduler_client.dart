import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'app_logger.dart';
import 'error_handler.dart';

/// Client to trigger on-demand scheduling of shared family tasks in Google Cloud Functions.
class CloudFamilySchedulerClient {
  final http.Client _httpClient;
  final FirebaseAuth? _auth;
  final String? _baseUrl;
  final AppLogger? _logger;
  final ErrorHandler? _errorHandler;

  CloudFamilySchedulerClient({
    http.Client? httpClient,
    FirebaseAuth? auth,
    String? baseUrl,
    AppLogger? logger,
    ErrorHandler? errorHandler,
  }) : _httpClient = httpClient ?? http.Client(),
       _auth = auth,
       _baseUrl = baseUrl,
       _logger = logger,
       _errorHandler = errorHandler;

  /// Resolves the endpoint URL for the Cloud Function.
  String resolveEndpointUrl() {
    final customUrl = _baseUrl;
    if (customUrl != null && customUrl.isNotEmpty) {
      final base = customUrl.endsWith('/')
          ? customUrl.substring(0, customUrl.length - 1)
          : customUrl;
      return '$base/processFamilySchedule';
    }

    String projectId = 'nothing-ever-happens-dev';
    try {
      if (Firebase.apps.isNotEmpty) {
        projectId = Firebase.app().options.projectId;
      }
    } catch (_) {
      // Use fallback if Firebase is not initialized
    }

    return 'https://us-central1-$projectId.cloudfunctions.net/processFamilySchedule';
  }

  /// Triggers cloud-side evaluation of family schedules for the specified [familyId].
  ///
  /// Returns `true` if the invocation succeeded (HTTP 200).
  /// Fails gracefully on network issues or unauthorized calls without throwing.
  Future<bool> triggerFamilyScheduleProcessing({
    required String familyId,
    DateTime? now,
  }) async {
    if (familyId.isEmpty) return false;

    try {
      User? user;
      if (_auth != null) {
        user = _auth.currentUser;
      } else {
        try {
          user = FirebaseAuth.instance.currentUser;
        } catch (_) {
          // FirebaseAuth may not be initialized in headless test environments
        }
      }

      if (user == null) {
        _logger?.debug(
          'cloud_scheduler',
          'No authenticated user; skipping cloud family scheduler trigger.',
        );
        return false;
      }

      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        _logger?.warning(
          'cloud_scheduler',
          'Unable to acquire ID token for user ${user.uid}',
        );
        return false;
      }

      final url = resolveEndpointUrl();
      final bodyMap = <String, dynamic>{
        'familyId': familyId,
        if (now != null) 'now': now.toUtc().toIso8601String(),
      };

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(bodyMap),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger?.info(
          'cloud_scheduler',
          'Successfully triggered cloud family scheduler for familyId=$familyId',
          data: {'statusCode': response.statusCode, 'body': response.body},
        );
        return true;
      } else {
        _logger?.warning(
          'cloud_scheduler',
          'Cloud family scheduler responded with status ${response.statusCode}',
          data: {'body': response.body},
        );
        return false;
      }
    } catch (e, st) {
      _logger?.error(
        'cloud_scheduler',
        'Exception while triggering cloud family scheduler',
        error: e,
        stackTrace: st,
      );
      _errorHandler?.report(e, stackTrace: st);
      return false;
    }
  }

  /// Closes the underlying HTTP client.
  void dispose() {
    _httpClient.close();
  }
}

final cloudFamilySchedulerClientProvider = Provider<CloudFamilySchedulerClient>(
  (ref) {
    FirebaseAuth? auth;
    try {
      if (Firebase.apps.isNotEmpty) {
        auth = FirebaseAuth.instance;
      }
    } catch (_) {}

    final client = CloudFamilySchedulerClient(
      auth: auth,
      logger: ref.watch(appLoggerProvider),
      errorHandler: ref.read(errorHandlerProvider),
    );
    ref.onDispose(() => client.dispose());
    return client;
  },
);
