import 'dart:math';
import 'package:flutter/material.dart';

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

  String _generateErrorCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  ErrorReport report(dynamic error, {StackTrace? stackTrace}) {
    final code = _generateErrorCode();
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
            const Expanded(
              child: Text('Error Occurred'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Something went wrong. Please share this error code with the developer:',
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
              'Details:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  report.error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
