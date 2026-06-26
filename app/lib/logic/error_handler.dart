import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n_extension.dart';

class ErrorReport {
  final String code;
  final dynamic error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  ErrorReport({
    required this.code,
    required this.error,
    this.stackTrace,
    required this.timestamp,
  });
}

class ErrorHandler {
  final List<ErrorReport> _history = [];

  List<ErrorReport> get history => List.unmodifiable(_history);

  String _generateErrorCode(dynamic error) {
    String prefix = 'ERR';
    String? detail;

    if (error is FirebaseException) {
      prefix = 'FIREBASE';
      detail = error.code.toUpperCase().replaceAll('-', '_');
    } else if (error is PlatformException) {
      prefix = 'PLATFORM';
      detail = error.code.toUpperCase().replaceAll('-', '_');
    } else if (error != null) {
      final typeStr = error.runtimeType.toString();
      if (typeStr.endsWith('Exception')) {
        prefix = typeStr
            .substring(0, typeStr.length - 'Exception'.length)
            .toUpperCase();
      } else if (typeStr.endsWith('Error')) {
        prefix = typeStr
            .substring(0, typeStr.length - 'Error'.length)
            .toUpperCase();
      } else {
        prefix = typeStr.toUpperCase();
      }
    }

    // Sanitize prefix (alphanumeric and underscores only)
    prefix = prefix.replaceAll(RegExp(r'[^A-Z0-9_]'), '');
    prefix = prefix.replaceAll(RegExp(r'^_+|_+$'), '');
    if (prefix.length > 12) {
      prefix = prefix.substring(0, 12);
    }
    if (prefix.isEmpty) {
      prefix = 'ERR';
    }

    // Sanitize detail
    if (detail != null) {
      detail = detail.replaceAll(RegExp(r'[^A-Z0-9_]'), '');
      if (detail.length > 24) {
        detail = detail.substring(0, 24);
      }
    }

    // Unique random suffix
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final suffix = List.generate(
      4,
      (index) => chars[random.nextInt(chars.length)],
    ).join();

    if (detail != null && detail.isNotEmpty) {
      return '${prefix}_${detail}_$suffix';
    }
    return '${prefix}_$suffix';
  }

  ErrorReport report(dynamic error, {StackTrace? stackTrace}) {
    final code = _generateErrorCode(error);
    final report = ErrorReport(
      code: code,
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
    );

    _history.add(report);

    // Log to console
    debugPrint('--- ERROR REPORT [$code] ---');
    debugPrint('Error: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace:\n$stackTrace');
    }
    debugPrint('----------------------------');

    return report;
  }

  void showErrorDialog(BuildContext context, ErrorReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(context.l10n.errorOccurred)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.somethingWentWrong,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                report.code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.details,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      report.error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (report.stackTrace != null) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        report.stackTrace.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }
}

final errorHandlerProvider = Provider<ErrorHandler>((ref) => ErrorHandler());
